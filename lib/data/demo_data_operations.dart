// Adds repeatable sample records for the presentation database.
part of 'stock_repository.dart';

/// Opt-in presentation data. All rows are inserted together or not at all.
extension DemoDataOperations on StockRepository {
  Future<void> ensurePresentationData() async {
    final db = await appDb.database;
    await db.transaction((txn) async {
      final seeded = await txn.query(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['presentation_data_seeded'],
        limit: 1,
      );
      if (seeded.isNotEmpty) return;

      final today = DateTime.now();
      String at(int daysAgo) => DateTime(
        today.year,
        today.month,
        today.day - daysAgo,
        10,
      ).toIso8601String();

      const opening = <String, double>{
        'PET_350': 800,
        'PET_600': 1100,
        'PET_1500': 500,
        'CAP_SCREW': 3000,
        'PVC_FILM': 24,
        'PE_FILM': 30,
        'FG_350': 420,
        'FG_600': 540,
        'FG_1500': 260,
      };
      const costs = <String, double>{
        'PET_350': 1.65,
        'PET_600': 2.10,
        'PET_1500': 3.80,
        'CAP_SCREW': 0.22,
        'PVC_FILM': 88,
        'PE_FILM': 105,
        'FG_350': 3.20,
        'FG_600': 4.10,
        'FG_1500': 7.40,
      };
      final balances = <String, double>{};
      final names = <String, String>{};
      for (final item in await txn.query('items')) {
        final code = item['code'] as String;
        names[code] = item['name'] as String;
        balances[code] = (item['current_quantity'] as num).toDouble();
        if (((item['unit_cost'] as num?) ?? 0).toDouble() <= 0) {
          await txn.update(
            'items',
            {
              'unit_cost': costs[code] ?? 0,
              'safety_stock': code.startsWith('PET_') ? 250 : 0,
              'min_quantity': code.startsWith('PET_') ? 400 : 0,
            },
            where: 'code = ?',
            whereArgs: [code],
          );
        }
      }

      Future<void> movement(
        String code,
        double delta,
        String type,
        int daysAgo,
        String note,
      ) async {
        final next = balances[code]! + delta;
        if (next < 0) throw StateError('Negative demo stock: $code');
        balances[code] = next;
        await txn.update(
          'items',
          {'current_quantity': next},
          where: 'code = ?',
          whereArgs: [code],
        );
        await txn.insert('stock_transactions', {
          'item_code': code,
          'item_name': names[code],
          'tx_type': type,
          'quantity': delta,
          'balance_after': next,
          'note': note,
          'created_at': at(daysAgo),
        });
      }

      for (final entry in opening.entries) {
        if (!names.containsKey(entry.key)) {
          throw AppException('Missing demo item ${entry.key}');
        }
        await movement(
          entry.key,
          entry.value,
          'adjust',
          8,
          'Demo opening stock',
        );
      }

      const purchases = [
        ('PET_350', 600.0, 1.60, 6, 'บริษัทตัวอย่าง เอ'),
        ('PET_600', 750.0, 2.05, 5, 'บริษัทตัวอย่าง บี'),
        ('PET_1500', 320.0, 3.75, 4, 'บริษัทตัวอย่าง ซี'),
        ('PET_350', 500.0, 1.68, 3, 'บริษัทตัวอย่าง เอ'),
        ('PET_600', 680.0, 2.12, 2, 'บริษัทตัวอย่าง บี'),
        ('PET_1500', 280.0, 3.90, 1, 'บริษัทตัวอย่าง ซี'),
      ];
      for (var i = 0; i < purchases.length; i++) {
        final p = purchases[i];
        await txn.insert('purchase_receipts', {
          'item_code': p.$1,
          'quantity': p.$2,
          'unit_price': p.$3,
          'supplier': p.$5,
          'reference': 'DEMO-BUY-${i + 1}',
          'purchased_at': at(p.$4).substring(0, 10),
          'created_at': at(p.$4),
        });
        await movement(
          p.$1,
          p.$2,
          'receive',
          p.$4,
          'ข้อมูลตัวอย่าง: รับซื้อ DEMO-BUY-${i + 1}',
        );
      }

      const customers = [
        'ร้านค้าตัวอย่าง เมืองน้ำ',
        'โรงแรมตัวอย่าง ริมคลอง',
        'สำนักงานตัวอย่าง กลางเมือง',
      ];
      final customerIds = <int>[];
      for (final name in customers) {
        customerIds.add(
          await txn.insert('b2b_customers', {
            'name': name,
            'contact_person': '',
            'phone': '',
            'address': '',
            'created_at': at(8),
          }),
        );
      }

      const sales = [
        ('FG_350', 90.0, 5.00, 6),
        ('FG_600', 120.0, 6.50, 5),
        ('FG_1500', 45.0, 11.00, 4),
        ('FG_350', 75.0, 5.20, 3),
        ('FG_600', 100.0, 6.70, 2),
        ('FG_1500', 55.0, 11.50, 1),
      ];
      for (var i = 0; i < sales.length; i++) {
        final s = sales[i];
        final when = at(s.$4);
        final id = await txn.insert('b2b_orders', {
          'customer_id': customerIds[i % customerIds.length],
          'status': 'fulfilled',
          'notes': 'ข้อมูลตัวอย่าง DEMO-SALE-${i + 1}',
          'created_at': when,
          'updated_at': when,
          'delivery_date': when.substring(0, 10),
          'confirmed_at': when,
          'fulfilled_at': when,
        });
        await txn.insert('b2b_order_lines', {
          'order_id': id,
          'item_code': s.$1,
          'quantity': s.$2,
          'unit_price': s.$3,
          'reserved_finished': 0,
          'production_quantity': 0,
        });
        await movement(
          s.$1,
          -s.$2,
          'b2b_dispatch',
          s.$4,
          'ข้อมูลตัวอย่าง: จัดส่ง DEMO-SALE-${i + 1}',
        );
      }

      for (final po in [
        ('PET_350', 'Bottle supplier A', 500.0, 1.62, 4),
        ('PET_600', 'Bottle supplier B', 700.0, 2.08, 2),
        ('PET_1500', 'Bottle supplier C', 300.0, 3.82, 1),
      ]) {
        final created = at(po.$5);
        await txn.insert('purchase_orders', {
          'item_code': po.$1,
          'item_name': names[po.$1],
          'quantity': po.$3,
          'unit_cost': po.$4,
          'total_cost': po.$3 * po.$4,
          'items_json': jsonEncode([
            {
              'item_code': po.$1,
              'item_name': names[po.$1],
              'quantity': po.$3,
              'unit_cost': po.$4,
            },
          ]),
          'status': 'pending',
          'created_at': created,
          'expected_date': at(po.$5 - 2).substring(0, 10),
        });
      }

      for (final recipe in [
        ('FG_350', 'PET_350', 1.0),
        ('FG_350', 'CAP_SCREW', 1.0),
        ('FG_600', 'PET_600', 1.0),
        ('FG_600', 'CAP_SCREW', 1.0),
        ('FG_1500', 'PET_1500', 1.0),
        ('FG_1500', 'CAP_SCREW', 1.0),
      ]) {
        await txn.insert('recipes', {
          'product_code': recipe.$1,
          'material_code': recipe.$2,
          'quantity': recipe.$3,
        });
      }
      for (final batch in [
        ('FG_350', 320.0, 7),
        ('FG_600', 420.0, 5),
        ('FG_1500', 180.0, 3),
      ]) {
        await txn.insert('production_batches', {
          'product_code': batch.$1,
          'product_name': names[batch.$1],
          'quantity': batch.$2,
          'note': 'Demo production batch',
          'created_at': at(batch.$3),
        });
      }
      await txn.insert('app_metadata', {
        'key': 'presentation_data_seeded',
        'value': 'v1',
      });
    });
  }
}
