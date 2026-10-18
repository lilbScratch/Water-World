import 'dart:convert';
import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../models.dart';
import '../order_models.dart';
import '../thai_labels.dart';
import 'app_db.dart';

part 'order_operations.dart';
part 'analytics_operations.dart';
part 'planning_data_operations.dart';

class StockRepository {
  final AppDb appDb;

  StockRepository({AppDb? appDb}) : appDb = appDb ?? AppDb.instance;

  Future<void> _queueSync(
    DatabaseExecutor db, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // อ่านรายการสินค้า
  Future<List<Item>> items({String? type}) async {
    final db = await appDb.database;

    String? where;
    List<Object?>? whereArgs;

    if (type == 'raw' || type == 'raw_material' || type == 'วัตถุดิบ') {
      where = "item_type IN ('raw', 'raw_material', 'วัตถุดิบ')";
    } else if (type == 'finished' ||
        type == 'finished_good' ||
        type == 'สินค้าสำเร็จรูป') {
      where = "item_type IN ('finished', 'finished_good', 'สินค้าสำเร็จรูป')";
    } else if (type != null) {
      where = 'item_type = ?';
      whereArgs = [type];
    }

    final rows = await db.query(
      'items',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name',
    );

    return rows.map(Item.fromMap).toList();
  }

  // นับจำนวนสินค้า
  Future<int> countItems() async {
    final db = await appDb.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM items');

    return (result.first['total'] as num).toInt();
  }

  // ค้นหาสินค้าจากรหัส
  Future<Item?> itemByCode(String code) async {
    final db = await appDb.database;

    final rows = await db.query(
      'items',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Item.fromMap(rows.first);
  }

  // อ่านสูตรการผลิตของสินค้า
  Future<List<RecipeLine>> recipeFor(String finishedCode) async {
    final db = await appDb.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        r.*,
        r.material_code AS raw_code,
        r.product_code AS finished_code,
        i.name AS raw_name,
        i.unit AS raw_unit
      FROM recipes r
      JOIN items i ON i.code = r.material_code
      WHERE r.product_code = ?
      ''',
      [finishedCode],
    );

    return rows.map(RecipeLine.fromMap).toList();
  }

  // อ่านสูตรการผลิตทั้งหมด
  Future<List<RecipeLine>> allRecipes() async {
    final db = await appDb.database;

    final rows = await db.rawQuery('''
      SELECT
        r.*,
        r.material_code AS raw_code,
        r.product_code AS finished_code,
        i.name AS raw_name,
        i.unit AS raw_unit
      FROM recipes r
      JOIN items i ON i.code = r.material_code
      ORDER BY r.product_code
    ''');

    return rows.map(RecipeLine.fromMap).toList();
  }

  // รับสินค้าเข้าคลัง
  Future<void> receive(String code, double quantity, {String note = ''}) async {
    if (quantity <= 0) {
      throw AppException('จำนวนรับเข้าต้องมากกว่า 0');
    }

    await _change(code, quantity, 'receive', note);
  }

  // จ่ายสินค้าออกจากคลัง
  Future<void> dispatch(
    String code,
    double quantity, {
    String note = '',
  }) async {
    if (quantity <= 0) {
      throw AppException('จำนวนจ่ายออกต้องมากกว่า 0');
    }

    await _change(code, -quantity, 'dispatch', note);
  }

  // ปรับยอดคงเหลือ
  Future<void> adjust(
    String code,
    double newBalance, {
    String note = '',
  }) async {
    if (newBalance < 0) {
      throw AppException('ยอดคงเหลือห้ามติดลบ');
    }

    final item = await itemByCode(code);

    if (item == null) {
      throw AppException('ไม่พบสินค้า $code');
    }

    final delta = newBalance - item.currentQuantity;

    if (delta == 0) return;

    await _change(code, delta, 'adjust', note);
  }

  // อ่านชื่อคอลัมน์ ใช้ได้ทั้ง Database และ Transaction
  Future<Set<String>> _tableColumns(
    DatabaseExecutor db,
    String tableName,
  ) async {
    final result = await db.rawQuery('PRAGMA table_info("$tableName")');

    return result.map((row) => row['name'] as String).toSet();
  }

  // สร้างแถวประวัติให้ตรงกับคอลัมน์ที่มีอยู่ในฐานข้อมูล
  Future<void> _insertStockTransaction(
    DatabaseExecutor txn, {
    required String code,
    required String name,
    required String type,
    required double quantity,
    required double before,
    required double after,
    String note = '',
    Object? itemId,
  }) async {
    final columns = await _tableColumns(txn, 'stock_transactions');

    final row = <String, Object?>{
      'item_code': code,
      'item_name': name,
      'tx_type': type,
      'quantity': quantity,
      'balance_after': after,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),

      // รองรับคอลัมน์จากฐานข้อมูลรุ่นเก่า
      'item_id': itemId,
      'transaction_type': type,
      'quantity_change': quantity,
      'quantity_before': before,
      'quantity_after': after,
      'unit_price_or_cost': 0,
      'reference_id': null,
    };

    row.removeWhere((key, value) => !columns.contains(key));

    await txn.insert('stock_transactions', row);
  }

  // เปลี่ยนยอดสต๊อกและบันทึกประวัติ
  Future<void> _change(
    String code,
    double delta,
    String type,
    String note,
  ) async {
    if (delta == 0) {
      throw AppException('ไม่มีการเปลี่ยนแปลงจำนวนสินค้า');
    }

    final db = await appDb.database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'items',
        where: 'code = ?',
        whereArgs: [code],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw AppException('ไม่พบสินค้า $code');
      }

      final row = rows.first;
      final current = (row['current_quantity'] as num).toDouble();
      final next = current + delta;
      final reserved = (row['reserved_quantity'] as num?)?.toDouble() ?? 0;

      if (next < 0) {
        throw AppException('สต๊อกไม่เพียงพอ');
      }
      if (delta < 0 && next < reserved) {
        throw AppException('Some stock is reserved for confirmed B2B orders.');
      }

      await txn.update(
        'items',
        {'current_quantity': next},
        where: 'code = ?',
        whereArgs: [code],
      );

      await _insertStockTransaction(
        txn,
        code: code,
        name: row['name']?.toString() ?? code,
        type: type,
        quantity: delta,
        before: current,
        after: next,
        note: note,
        itemId: row['id'],
      );
      await _queueSync(
        txn,
        entityType: 'stock',
        entityId: code,
        operation: 'adjust',
        payload: {
          'code': code,
          'delta': delta,
          'balance': next,
          'type': type,
          'note': note,
        },
      );
    });
  }

  // ผลิตสินค้า ตัดวัตถุดิบและเพิ่มสินค้าสำเร็จรูป
  Future<void> produce(
    String finishedCode,
    double quantity, {
    String note = '',
  }) async {
    if (quantity <= 0) {
      throw AppException('จำนวนผลิตต้องมากกว่า 0');
    }

    final db = await appDb.database;

    await db.transaction((txn) async {
      final finishedRows = await txn.query(
        'items',
        where: 'code = ?',
        whereArgs: [finishedCode],
        limit: 1,
      );

      if (finishedRows.isEmpty) {
        throw AppException('ไม่พบสินค้าสำเร็จรูป');
      }

      final recipes = await txn.query(
        'recipes',
        where: 'product_code = ?',
        whereArgs: [finishedCode],
      );

      if (recipes.isEmpty) {
        throw AppException('ไม่พบสูตรการผลิต');
      }

      // ตรวจสอบวัตถุดิบก่อนตัดสต๊อก
      for (final recipe in recipes) {
        final rawCode = recipe['material_code'] as String;
        final needed = (recipe['quantity'] as num).toDouble() * quantity;

        final rawRows = await txn.query(
          'items',
          where: 'code = ?',
          whereArgs: [rawCode],
          limit: 1,
        );

        if (rawRows.isEmpty) {
          throw AppException('ไม่พบวัตถุดิบ $rawCode');
        }

        final current = (rawRows.first['current_quantity'] as num).toDouble();

        final reserved =
            (rawRows.first['reserved_quantity'] as num?)?.toDouble() ?? 0;
        if (current - reserved < needed) {
          throw AppException('วัตถุดิบ ${rawRows.first['name']} ไม่เพียงพอ');
        }
      }

      // ตัดวัตถุดิบ
      for (final recipe in recipes) {
        final rawCode = recipe['material_code'] as String;
        final needed = (recipe['quantity'] as num).toDouble() * quantity;

        final rawRows = await txn.query(
          'items',
          where: 'code = ?',
          whereArgs: [rawCode],
          limit: 1,
        );

        final raw = rawRows.first;
        final current = (raw['current_quantity'] as num).toDouble();
        final next = current - needed;

        await txn.update(
          'items',
          {'current_quantity': next},
          where: 'code = ?',
          whereArgs: [rawCode],
        );

        await _insertStockTransaction(
          txn,
          code: rawCode,
          name: raw['name']?.toString() ?? rawCode,
          type: 'production_consume',
          quantity: -needed,
          before: current,
          after: next,
          note: 'ใช้ผลิต $finishedCode จำนวน $quantity $note',
          itemId: raw['id'],
        );
      }

      // เพิ่มสินค้าสำเร็จรูป
      final finished = finishedRows.first;
      final currentFinished = (finished['current_quantity'] as num).toDouble();
      final nextFinished = currentFinished + quantity;

      await txn.update(
        'items',
        {'current_quantity': nextFinished},
        where: 'code = ?',
        whereArgs: [finishedCode],
      );

      await _insertStockTransaction(
        txn,
        code: finishedCode,
        name: finished['name']?.toString() ?? finishedCode,
        type: 'production_output',
        quantity: quantity,
        before: currentFinished,
        after: nextFinished,
        note: note,
        itemId: finished['id'],
      );

      // บันทึกประวัติการผลิตให้ตรงกับ app_db.dart
      await txn.insert('production_batches', {
        'product_code': finishedCode,
        'product_name': finished['name']?.toString() ?? finishedCode,
        'quantity': quantity,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _queueSync(
        txn,
        entityType: 'production',
        entityId: '$finishedCode:${DateTime.now().microsecondsSinceEpoch}',
        operation: 'create',
        payload: {
          'product_code': finishedCode,
          'quantity': quantity,
          'note': note,
        },
      );
    });
  }

  // อ่านประวัติการเคลื่อนไหวของสินค้า
  Future<List<StockTx>> history({
    String filter = 'all',
    int limit = 200,
  }) async {
    final db = await appDb.database;
    final columns = await _tableColumns(db, 'stock_transactions');

    final typeColumn = columns.contains('tx_type')
        ? 'tx_type'
        : 'transaction_type';

    final rows = await db.rawQuery('''
      SELECT * FROM stock_transactions
      ${filter == 'all' ? '' : 'WHERE $typeColumn = ?'}
      ORDER BY id DESC
      LIMIT ?
      ''', filter == 'all' ? [limit] : [filter, limit]);

    return rows.map(StockTx.fromMap).toList();
  }

  // สรุปการใช้วัตถุดิบรายวัน
  Future<Map<String, double>> consumptionStats(
    String code, {
    int days = 30,
  }) async {
    if (days <= 0) {
      throw ArgumentError('days ต้องมากกว่า 0');
    }

    final db = await appDb.database;
    final columns = await _tableColumns(db, 'stock_transactions');

    final codeColumn = columns.contains('item_code') ? 'item_code' : null;
    final typeColumn = columns.contains('tx_type')
        ? 'tx_type'
        : 'transaction_type';
    final quantityColumn = columns.contains('quantity')
        ? 'quantity'
        : 'quantity_change';

    if (codeColumn == null) {
      throw AppException(
        'ตารางประวัติสินค้าไม่มีคอลัมน์ item_code กรุณาตรวจสอบฐานข้อมูล',
      );
    }

    final cutoff = DateTime.now()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    final rows = await db.rawQuery(
      '''
      SELECT date(created_at) AS day,
             SUM(-$quantityColumn) AS used
      FROM stock_transactions
      WHERE $codeColumn = ?
        AND $typeColumn = 'production_consume'
        AND $quantityColumn < 0
        AND date(created_at) >= date(?)
      GROUP BY date(created_at)
      ''',
      [code, cutoff],
    );

    final daily = <String, double>{};

    for (final row in rows) {
      final day = row['day'];
      final used = row['used'];

      if (day != null && used != null) {
        daily[day as String] = (used as num).toDouble();
      }
    }

    final values = <double>[];

    for (var i = 0; i < days; i++) {
      final date = DateTime.now()
          .subtract(Duration(days: days - 1 - i))
          .toIso8601String()
          .substring(0, 10);

      values.add(daily[date] ?? 0);
    }

    final average = values.fold<double>(0, (sum, value) => sum + value) / days;

    final variance =
        values.fold<double>(
          0,
          (sum, value) => sum + math.pow(value - average, 2).toDouble(),
        ) /
        days;

    return {'average': average, 'stddev': math.sqrt(variance)};
  }

  // บันทึกนโยบาย Safety Stock
  Future<void> saveStockPolicy({
    required String code,
    required int leadTimeDays,
    required int targetDays,
    required double serviceLevelZ,
    double? safetyStock,
    double? minQuantity,
  }) async {
    final db = await appDb.database;

    await db.update(
      'items',
      {
        'lead_time_days': leadTimeDays,
        'target_days': targetDays,
        'service_level_z': serviceLevelZ,
        'safety_stock': safetyStock ?? 0,
        'min_quantity': minQuantity ?? 0,
      },
      where: 'code = ?',
      whereArgs: [code],
    );
  }

  // สร้างใบสั่งซื้อแบบร่าง
  Future<int> createPurchaseOrder(List<Map<String, Object?>> items) async {
    final db = await appDb.database;

    return db.insert('purchase_orders', {
      'status': 'draft',
      'items_json': jsonEncode(items),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // อ่านใบสั่งซื้อ
  Future<List<Map<String, Object?>>> purchaseOrders() async {
    final db = await appDb.database;

    return db.query('purchase_orders', orderBy: 'id DESC');
  }

  Future<int> addB2BCustomer({
    required String name,
    String contactPerson = '',
    String phone = '',
    String address = '',
  }) async {
    final db = await appDb.database;
    return db.transaction((txn) async {
      final id = await txn.insert('b2b_customers', {
        'name': name.trim(),
        'contact_person': contactPerson.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _queueSync(
        txn,
        entityType: 'b2b_customer',
        entityId: '$id',
        operation: 'create',
        payload: {
          'name': name.trim(),
          'contact_person': contactPerson.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
        },
      );
      return id;
    });
  }
}
