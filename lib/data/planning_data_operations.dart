part of 'stock_repository.dart';

extension PlanningDataOperations on StockRepository {
  Future<void> saveRecipe({
    required String productCode,
    required List<Map<String, Object?>> materials,
    required int productionLeadDays,
  }) async {
    if (materials.isEmpty ||
        productionLeadDays < 0 ||
        productionLeadDays > 365) {
      throw AppException('กรุณาเพิ่มวัตถุดิบและระบุระยะเวลาผลิต 0–365 วัน');
    }
    if (materials.map((m) => m['material_code']).toSet().length !=
        materials.length) {
      throw AppException('ไม่สามารถระบุวัตถุดิบซ้ำในสูตรเดียวกันได้');
    }
    final db = await appDb.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'items',
        where: 'code = ?',
        whereArgs: [productCode],
      );
      if (rows.isEmpty ||
          ![
            'finished',
            'finished_good',
            'สินค้าสำเร็จรูป',
          ].contains(rows.first['item_type'])) {
        throw AppException('กรุณาเลือกสินค้าสำเร็จรูป');
      }
      if ((await txn.query(
        'b2b_material_allocations',
        where: 'product_code = ?',
        whereArgs: [productCode],
      )).isNotEmpty) {
        throw AppException(
          'กรุณาผลิตหรือยกเลิกคำสั่งผลิตที่สำรองวัตถุดิบไว้ก่อนแก้ไขสูตรนี้',
        );
      }
      for (final material in materials) {
        final quantity = (material['quantity'] as num).toDouble();
        final raw = await txn.query(
          'items',
          where: 'code = ?',
          whereArgs: [material['material_code']],
        );
        if (!quantity.isFinite ||
            quantity <= 0 ||
            raw.isEmpty ||
            ![
              'raw',
              'raw_material',
              'วัตถุดิบ',
            ].contains(raw.first['item_type'])) {
          throw AppException('กรุณาเลือกวัตถุดิบและระบุปริมาณมากกว่า 0');
        }
      }
      await txn.delete(
        'recipes',
        where: 'product_code = ?',
        whereArgs: [productCode],
      );
      for (final material in materials) {
        await txn.insert('recipes', {
          'product_code': productCode,
          'material_code': material['material_code'],
          'quantity': material['quantity'],
        });
      }
      await txn.update(
        'items',
        {'production_lead_days': productionLeadDays},
        where: 'code = ?',
        whereArgs: [productCode],
      );
    });
  }

  Future<int> recordPurchaseReceipt({
    required String itemCode,
    required double quantity,
    required double unitPrice,
    required String supplier,
    required DateTime purchasedAt,
    String reference = '',
  }) async {
    final now = DateTime.now();
    if (!quantity.isFinite ||
        quantity <= 0 ||
        !unitPrice.isFinite ||
        unitPrice < 0 ||
        supplier.trim().isEmpty) {
      throw AppException(
        'กรุณาระบุผู้จำหน่าย จำนวนรับเข้ามากกว่า 0 และราคาซื้อจริงตั้งแต่ 0 ขึ้นไป',
      );
    }
    if (dateOnly(purchasedAt).compareTo(dateOnly(now)) > 0) {
      throw AppException('วันที่ซื้อของสินค้าที่รับแล้วต้องไม่เป็นวันในอนาคต');
    }
    final db = await appDb.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'items',
        where: 'code = ?',
        whereArgs: [itemCode],
      );
      if (rows.isEmpty ||
          ![
            'raw',
            'raw_material',
            'วัตถุดิบ',
          ].contains(rows.first['item_type'])) {
        throw AppException('กรุณาเลือกวัตถุดิบ');
      }
      final item = rows.single;
      final before = (item['current_quantity'] as num).toDouble();
      final id = await txn.insert('purchase_receipts', {
        'item_code': itemCode,
        'quantity': quantity,
        'unit_price': unitPrice,
        'supplier': supplier.trim(),
        'reference': reference.trim(),
        'purchased_at': dateOnly(purchasedAt),
        'created_at': now.toIso8601String(),
      });
      await txn.update(
        'items',
        {'current_quantity': before + quantity, 'unit_cost': unitPrice},
        where: 'code = ?',
        whereArgs: [itemCode],
      );
      await _insertStockTransaction(
        txn,
        code: itemCode,
        name: item['name'] as String,
        type: 'receive',
        quantity: quantity,
        before: before,
        after: before + quantity,
        note: 'Purchase receipt #$id ${supplier.trim()} ${reference.trim()}',
      );
      return id;
    });
  }

  Future<List<Map<String, Object?>>> purchaseReceipts() async {
    final db = await appDb.database;
    return db.rawQuery(
      '''SELECT r.*, i.name AS item_name, i.unit FROM purchase_receipts r
      JOIN items i ON i.code = r.item_code ORDER BY r.purchased_at DESC, r.id DESC''',
    );
  }
}
