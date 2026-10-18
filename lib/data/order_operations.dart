part of 'stock_repository.dart';

extension OrderOperations on StockRepository {
  Future<List<Map<String, Object?>>> b2bCustomers({String search = ''}) async {
    final db = await appDb.database;
    final term = '%${search.trim()}%';
    return db.query(
      'b2b_customers',
      where: search.trim().isEmpty
          ? null
          : 'name LIKE ? OR phone LIKE ? OR contact_person LIKE ?',
      whereArgs: search.trim().isEmpty ? null : [term, term, term],
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<OrderPlan> precheckB2BOrder(
    List<Map<String, Object?>> lines, {
    DateTime? deliveryDate,
  }) async {
    final db = await appDb.database;
    return db.transaction((txn) => _plan(txn, lines, deliveryDate));
  }

  Future<OrderPlan> _plan(
    DatabaseExecutor db,
    List<Map<String, Object?>> lines,
    DateTime? deliveryDate,
  ) async {
    if (lines.isEmpty) throw AppException('กรุณาเพิ่มสินค้าอย่างน้อย 1 รายการ');
    if (lines.map((l) => l['item_code']).toSet().length != lines.length) {
      throw AppException('ไม่สามารถระบุสินค้าซ้ำในคำสั่งซื้อเดียวกันได้');
    }
    final products = <ProductPlan>[];
    final needed = <String, double>{};
    final missing = <String>[];
    var productionDays = 0;
    for (final line in lines) {
      final quantity = (line['quantity'] as num).toDouble();
      final price = (line['unit_price'] as num?)?.toDouble() ?? 0;
      if (!quantity.isFinite || quantity <= 0 || !price.isFinite || price < 0) {
        throw AppException(
          'กรุณาระบุจำนวนมากกว่า 0 และราคาขายตั้งแต่ 0 ขึ้นไป',
        );
      }
      final rows = await db.query(
        'items',
        where: 'code = ?',
        whereArgs: [line['item_code']],
      );
      if (rows.isEmpty ||
          ![
            'finished',
            'finished_good',
            'สินค้าสำเร็จรูป',
          ].contains(rows.first['item_type'])) {
        throw AppException('กรุณาเลือกสินค้าสำเร็จรูป');
      }
      final product = Item.fromMap(rows.first);
      final fromStock = math.min(
        quantity,
        math.max(0.0, product.availableQuantity),
      );
      final shortage = quantity - fromStock;
      products.add(ProductPlan(product, quantity, fromStock, shortage));
      if (shortage == 0) continue;
      productionDays = math.max(productionDays, product.productionLeadDays);
      final recipes = await db.query(
        'recipes',
        where: 'product_code = ?',
        whereArgs: [product.code],
      );
      if (recipes.isEmpty) missing.add(product.name);
      for (final recipe in recipes) {
        final amount = (recipe['quantity'] as num).toDouble();
        if (!amount.isFinite || amount <= 0) {
          throw AppException('ปริมาณวัตถุดิบในสูตรต้องมากกว่า 0');
        }
        final code = recipe['material_code'] as String;
        needed[code] = (needed[code] ?? 0) + amount * shortage;
      }
    }
    final materials = <MaterialPlan>[];
    var supplierDays = 0;
    for (final entry in needed.entries) {
      final rows = await db.query(
        'items',
        where: 'code = ?',
        whereArgs: [entry.key],
      );
      if (rows.isEmpty) {
        throw AppException('ไม่พบวัตถุดิบ ${entry.key} ในสูตรการผลิต');
      }
      final material = Item.fromMap(rows.first);
      final requirement = MaterialPlan(material, entry.value);
      materials.add(requirement);
      if (requirement.shortage > 0) {
        supplierDays = math.max(supplierDays, material.leadTimeDays);
      }
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return OrderPlan(
      products: products,
      materials: materials,
      missingRecipes: missing,
      earliestDelivery: today.add(
        Duration(days: supplierDays + productionDays),
      ),
      requestedDelivery: deliveryDate == null
          ? null
          : DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day),
    );
  }

  Future<int> createB2BOrder({
    required int customerId,
    required List<Map<String, Object?>> items,
    String notes = '',
    DateTime? deliveryDate,
  }) async {
    final db = await appDb.database;
    return db.transaction((txn) async {
      if ((await txn.query(
        'b2b_customers',
        where: 'id = ?',
        whereArgs: [customerId],
      )).isEmpty) {
        throw AppException('ไม่พบลูกค้านี้ในระบบ');
      }
      await _plan(txn, items, deliveryDate);
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('b2b_orders', {
        'customer_id': customerId,
        'status': 'draft',
        'notes': notes.trim(),
        'delivery_date': dateOnly(deliveryDate ?? DateTime.now()),
        'created_at': now,
        'updated_at': now,
      });
      for (final line in items) {
        await txn.insert('b2b_order_lines', {
          'order_id': id,
          'item_code': line['item_code'],
          'quantity': line['quantity'],
          'unit_price': line['unit_price'] ?? 0,
        });
      }
      await _queueSync(
        txn,
        entityType: 'b2b_order',
        entityId: '$id',
        operation: 'create',
        payload: {
          'customer_id': customerId,
          'items': items,
          'delivery_date': dateOnly(deliveryDate ?? DateTime.now()),
        },
      );
      return id;
    });
  }

  Future<void> confirmB2BOrder(int id) async {
    final db = await appDb.database;
    await db.transaction((txn) async {
      final order = await _orderWithStatus(txn, id, ['draft']);
      final lines = await txn.query(
        'b2b_order_lines',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      final plan = await _plan(
        txn,
        lines,
        DateTime.tryParse(order['delivery_date']?.toString() ?? ''),
      );
      if (!plan.canConfirm) {
        final shortages = plan.materials
            .where((m) => m.shortage > 0)
            .map(
              (m) =>
                  '${m.material.name}: ขาด ${m.shortage.toStringAsFixed(2)} ${m.material.unit}',
            )
            .join('; ');
        throw AppException(
          '${plan.status}. $shortages '
          '${plan.missingRecipes.isEmpty ? 'คาดว่าพร้อมส่งได้เร็วที่สุด: ${dateOnly(plan.earliestDelivery)}.' : 'กรุณากำหนดสูตรการผลิต: ${plan.missingRecipes.join(', ')}.'}',
        );
      }
      for (final product in plan.products) {
        await txn.rawUpdate(
          'UPDATE items SET reserved_quantity = reserved_quantity + ? WHERE code = ?',
          [product.fromStock, product.product.code],
        );
        await txn.update(
          'b2b_order_lines',
          {
            'reserved_finished': product.fromStock,
            'production_quantity': product.toProduce,
          },
          where: 'order_id = ? AND item_code = ?',
          whereArgs: [id, product.product.code],
        );
        if (product.toProduce == 0) continue;
        final recipes = await txn.query(
          'recipes',
          where: 'product_code = ?',
          whereArgs: [product.product.code],
        );
        for (final recipe in recipes) {
          final amount =
              (recipe['quantity'] as num).toDouble() * product.toProduce;
          await txn.insert('b2b_material_allocations', {
            'order_id': id,
            'product_code': product.product.code,
            'material_code': recipe['material_code'],
            'quantity': amount,
          });
          await txn.rawUpdate(
            'UPDATE items SET reserved_quantity = reserved_quantity + ? WHERE code = ?',
            [amount, recipe['material_code']],
          );
        }
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'b2b_orders',
        {
          'status': plan.needsProduction ? 'awaiting_production' : 'confirmed',
          'confirmed_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<Map<String, Object?>> _orderWithStatus(
    DatabaseExecutor txn,
    int id,
    List<String> statuses,
  ) async {
    final rows = await txn.query(
      'b2b_orders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty || !statuses.contains(rows.first['status'])) {
      throw AppException(
        'ดำเนินการได้เฉพาะคำสั่งซื้อสถานะ ${statuses.map(orderStatusLabel).join(' หรือ ')}',
      );
    }
    return rows.first;
  }

  Future<void> produceB2BOrder(int id) async {
    final db = await appDb.database;
    await db.transaction((txn) async {
      await _orderWithStatus(txn, id, ['awaiting_production']);
      final allocations = await txn.query(
        'b2b_material_allocations',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      for (final allocation in allocations) {
        final raw = (await txn.query(
          'items',
          where: 'code = ?',
          whereArgs: [allocation['material_code']],
        )).single;
        final quantity = (allocation['quantity'] as num).toDouble();
        final current = (raw['current_quantity'] as num).toDouble();
        final reserved = (raw['reserved_quantity'] as num).toDouble();
        if (current < quantity || reserved < quantity) {
          throw AppException(
            'ยอดวัตถุดิบที่สำรองไว้เปลี่ยนแปลง กรุณาตรวจสอบอีกครั้ง',
          );
        }
        await txn.update(
          'items',
          {
            'current_quantity': current - quantity,
            'reserved_quantity': reserved - quantity,
          },
          where: 'code = ?',
          whereArgs: [raw['code']],
        );
        await _insertStockTransaction(
          txn,
          code: raw['code'] as String,
          name: raw['name'] as String,
          type: 'production_consume',
          quantity: -quantity,
          before: current,
          after: current - quantity,
          note: 'ผลิตตามคำสั่งซื้อขายส่ง #$id',
        );
      }
      final lines = await txn.query(
        'b2b_order_lines',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      for (final line in lines) {
        final quantity = (line['production_quantity'] as num).toDouble();
        if (quantity == 0) continue;
        final item = (await txn.query(
          'items',
          where: 'code = ?',
          whereArgs: [line['item_code']],
        )).single;
        final current = (item['current_quantity'] as num).toDouble();
        await txn.rawUpdate(
          'UPDATE items SET current_quantity = current_quantity + ?, reserved_quantity = reserved_quantity + ? WHERE code = ?',
          [quantity, quantity, item['code']],
        );
        await _insertStockTransaction(
          txn,
          code: item['code'] as String,
          name: item['name'] as String,
          type: 'production_output',
          quantity: quantity,
          before: current,
          after: current + quantity,
          note: 'ผลิตตามคำสั่งซื้อขายส่ง #$id',
        );
        await txn.insert('production_batches', {
          'product_code': item['code'],
          'product_name': item['name'],
          'quantity': quantity,
          'note': 'คำสั่งซื้อขายส่ง #$id',
          'created_at': DateTime.now().toIso8601String(),
        });
        await txn.update(
          'b2b_order_lines',
          {'production_quantity': 0, 'reserved_finished': line['quantity']},
          where: 'id = ?',
          whereArgs: [line['id']],
        );
      }
      await txn.delete(
        'b2b_material_allocations',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'b2b_orders',
        {'status': 'confirmed', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> fulfillB2BOrder(int id) async {
    final db = await appDb.database;
    await db.transaction((txn) async {
      await _orderWithStatus(txn, id, ['confirmed']);
      final lines = await txn.query(
        'b2b_order_lines',
        where: 'order_id = ?',
        whereArgs: [id],
      );
      for (final line in lines) {
        final item = (await txn.query(
          'items',
          where: 'code = ?',
          whereArgs: [line['item_code']],
        )).single;
        final quantity = (line['quantity'] as num).toDouble();
        final current = (item['current_quantity'] as num).toDouble();
        final reserved = (item['reserved_quantity'] as num).toDouble();
        if (current < quantity || reserved < quantity) {
          throw AppException(
            'ยอดสินค้าที่สำรองไว้เปลี่ยนแปลง กรุณาตรวจสอบอีกครั้ง',
          );
        }
        await txn.update(
          'items',
          {
            'current_quantity': current - quantity,
            'reserved_quantity': reserved - quantity,
          },
          where: 'code = ?',
          whereArgs: [item['code']],
        );
        await _insertStockTransaction(
          txn,
          code: item['code'] as String,
          name: item['name'] as String,
          type: 'b2b_dispatch',
          quantity: -quantity,
          before: current,
          after: current - quantity,
          note: 'คำสั่งซื้อขายส่ง #$id',
        );
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'b2b_orders',
        {'status': 'fulfilled', 'fulfilled_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> cancelB2BOrder(int id) async {
    final db = await appDb.database;
    await db.transaction((txn) async {
      final order = await _orderWithStatus(txn, id, [
        'draft',
        'confirmed',
        'awaiting_production',
      ]);
      if (order['status'] != 'draft') {
        final lines = await txn.query(
          'b2b_order_lines',
          where: 'order_id = ?',
          whereArgs: [id],
        );
        final materials = await txn.query(
          'b2b_material_allocations',
          where: 'order_id = ?',
          whereArgs: [id],
        );
        for (final line in lines) {
          await txn.rawUpdate(
            'UPDATE items SET reserved_quantity = reserved_quantity - ? WHERE code = ?',
            [line['reserved_finished'], line['item_code']],
          );
        }
        for (final material in materials) {
          await txn.rawUpdate(
            'UPDATE items SET reserved_quantity = reserved_quantity - ? WHERE code = ?',
            [material['quantity'], material['material_code']],
          );
        }
        await txn.delete(
          'b2b_material_allocations',
          where: 'order_id = ?',
          whereArgs: [id],
        );
      }
      await txn.update(
        'b2b_orders',
        {'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Map<String, Object?>>> b2bOrders() async {
    final db = await appDb.database;
    return db.rawQuery(
      '''SELECT o.*, c.name AS customer_name,
      (SELECT COUNT(*) FROM b2b_order_lines l WHERE l.order_id = o.id) AS line_count,
      (SELECT SUM(quantity * unit_price) FROM b2b_order_lines l WHERE l.order_id = o.id) AS total
      FROM b2b_orders o JOIN b2b_customers c ON c.id = o.customer_id ORDER BY o.id DESC''',
    );
  }
}
