import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:water_world/data/app_db.dart';
import 'package:water_world/data/stock_repository.dart';

void main() {
  late Directory testDir;
  late AppDb testDb;
  late StockRepository repo;
  late dynamic db;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('water_world_test_');

    testDb = AppDb.forTesting(
      factory: databaseFactoryFfi,
      path: p.join(testDir.path, 'test.db'),
    );

    db = await testDb.database;
    repo = StockRepository(appDb: testDb);

    // เพิ่มสินค้าสำเร็จรูปสำหรับทดสอบ
    await db.insert('items', {
      'code': 'WATER_350_12',
      'name': 'Water 350 ml',
      'item_type': 'finished',
      'unit': 'pack',
      'current_quantity': 0,
      'unit_cost': 0,
      'min_quantity': 0,
      'safety_stock': 0,
      'reserved_quantity': 0,
      'lead_time_days': 0,
      'target_days': 0,
      'service_level_z': 1.65,
    });

    // สูตรการผลิต: ใช้ PET_350 จำนวน 1 หน่วยต่อสินค้า 1 หน่วย
    await db.insert('recipes', {
      'product_code': 'WATER_350_12',
      'material_code': 'PET_350',
      'quantity': 1,
    });
  });

  tearDown(() async {
    await testDb.close();

    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('StockRepository', () {
    test('รับสินค้าเข้าคลังแล้วจำนวนคงเหลือเพิ่มขึ้น', () async {
      await repo.receive('PET_350', 120, note: 'ทดสอบรับสินค้า');

      final result = await db.query(
        'items',
        columns: ['current_quantity'],
        where: 'code = ?',
        whereArgs: ['PET_350'],
      );

      expect(result, isNotEmpty);
      expect((result.first['current_quantity'] as num).toDouble(), 120);
    });

    test('ผลิตสินค้าแล้ววัตถุดิบลดและสินค้าสำเร็จรูปเพิ่ม', () async {
      await repo.receive('PET_350', 20);

      await repo.produce('WATER_350_12', 10, note: 'ทดสอบการผลิต');

      final rawResult = await db.query(
        'items',
        columns: ['current_quantity'],
        where: 'code = ?',
        whereArgs: ['PET_350'],
      );

      final finishedResult = await db.query(
        'items',
        columns: ['current_quantity'],
        where: 'code = ?',
        whereArgs: ['WATER_350_12'],
      );

      expect((rawResult.first['current_quantity'] as num).toDouble(), 10);

      expect((finishedResult.first['current_quantity'] as num).toDouble(), 10);
    });

    test('วัตถุดิบไม่เพียงพอแล้วการผลิตต้องไม่สำเร็จ', () async {
      await repo.receive('PET_350', 2);

      await expectLater(repo.produce('WATER_350_12', 10), throwsA(anything));

      final result = await db.query(
        'items',
        columns: ['current_quantity'],
        where: 'code = ?',
        whereArgs: ['PET_350'],
      );

      expect((result.first['current_quantity'] as num).toDouble(), 2);
    });

    test('เบิกสินค้าแล้วจำนวนคงเหลือลดลง', () async {
      await repo.receive('WATER_350_12', 10);

      await repo.dispatch('WATER_350_12', 4, note: 'ทดสอบเบิกสินค้า');

      final result = await db.query(
        'items',
        columns: ['current_quantity'],
        where: 'code = ?',
        whereArgs: ['WATER_350_12'],
      );

      expect((result.first['current_quantity'] as num).toDouble(), 6);
    });

    test('เบิกสินค้าเกินจำนวนคงเหลือแล้วต้องไม่สำเร็จ', () async {
      await repo.receive('WATER_350_12', 2);

      await expectLater(repo.dispatch('WATER_350_12', 5), throwsA(anything));
    });
  });
}
