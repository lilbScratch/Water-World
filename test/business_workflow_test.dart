import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_world/data/app_db.dart';
import 'package:water_world/data/stock_repository.dart';
import 'package:water_world/order_models.dart';

void main() {
  late Directory folder;
  late AppDb appDb;
  late Database db;
  late StockRepository repo;
  late int customer;
  DateTime delivery() => DateTime.now().add(const Duration(days: 7));
  List<Map<String, Object?>> lines(double quantity) => [
    {'item_code': 'FG_350', 'quantity': quantity, 'unit_price': 12.0},
  ];
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('water_world_business_');
    appDb = AppDb.forTesting(
      factory: databaseFactoryFfi,
      path: p.join(folder.path, 'test.db'),
    );
    db = await appDb.database;
    repo = StockRepository(appDb: appDb);
    customer = await repo.addB2BCustomer(
      name: 'Restaurant',
      phone: '099000001',
    );
    await repo.saveRecipe(
      productCode: 'FG_350',
      materials: [
        {'material_code': 'PET_350', 'quantity': 1.0},
        {'material_code': 'CAP_SCREW', 'quantity': 1.0},
      ],
      productionLeadDays: 1,
    );
    await db.update(
      'items',
      {'lead_time_days': 5},
      where: 'code = ?',
      whereArgs: ['PET_350'],
    );
  });
  tearDown(() async {
    await appDb.close();
    await folder.delete(recursive: true);
  });

  test(
    'precheck aggregates material deficits and supplier plus production lead time',
    () async {
      await repo.receive('FG_350', 2);
      await repo.receive('PET_350', 1);
      await repo.receive('CAP_SCREW', 5);
      final plan = await repo.precheckB2BOrder(
        lines(7),
        deliveryDate: delivery(),
      );
      expect(plan.products.single.toProduce, 5);
      expect(
        plan.materials.firstWhere((m) => m.material.code == 'PET_350').shortage,
        4,
      );
      final today = DateTime.now();
      expect(
        dateOnly(plan.earliestDelivery),
        dateOnly(
          DateTime(
            today.year,
            today.month,
            today.day,
          ).add(const Duration(days: 6)),
        ),
      );
      expect(plan.canConfirm, isFalse);
      final id = await repo.createB2BOrder(
        customerId: customer,
        items: lines(7),
        deliveryDate: delivery(),
      );
      await expectLater(repo.confirmB2BOrder(id), throwsException);
      expect((await repo.b2bOrders()).single['status'], 'draft');
      expect((await repo.itemByCode('FG_350'))!.reservedQuantity, 0);
    },
  );

  test(
    'reserve goods and shared raw materials, produce, fulfill and recognize sales once',
    () async {
      await repo.receive('FG_350', 2);
      await repo.receive('PET_350', 5);
      await repo.receive('CAP_SCREW', 5);
      final id = await repo.createB2BOrder(
        customerId: customer,
        items: lines(7),
        deliveryDate: delivery(),
      );
      await repo.confirmB2BOrder(id);
      expect((await repo.b2bOrders()).single['status'], 'awaiting_production');
      expect((await repo.itemByCode('FG_350'))!.reservedQuantity, 2);
      expect((await repo.itemByCode('PET_350'))!.reservedQuantity, 5);
      await expectLater(repo.produce('FG_350', 1), throwsException);
      await expectLater(repo.dispatch('PET_350', 1), throwsException);
      await expectLater(repo.fulfillB2BOrder(id), throwsException);
      await expectLater(repo.confirmB2BOrder(id), throwsException);
      await repo.produceB2BOrder(id);
      expect((await repo.itemByCode('FG_350'))!.reservedQuantity, 7);
      expect((await repo.itemByCode('PET_350'))!.currentQuantity, 0);
      await expectLater(repo.dispatch('FG_350', 1), throwsException);
      final before =
          (await repo.dashboardStats(days: 1)).first['summary'] as Map;
      expect(before['today_revenue'], 0);
      await repo.fulfillB2BOrder(id);
      await expectLater(repo.fulfillB2BOrder(id), throwsException);
      final summary =
          (await repo.dashboardStats(days: 1)).first['summary'] as Map;
      expect(summary['today_revenue'], 84);
      expect(summary['today_produced'], 5);
      expect((await repo.itemByCode('FG_350'))!.reservedQuantity, 0);
      expect((await repo.itemByCode('FG_350'))!.currentQuantity, 0);
    },
  );

  test(
    'cancelling production allocation releases raw and finished reservations',
    () async {
      await repo.receive('FG_350', 2);
      await repo.receive('PET_350', 5);
      await repo.receive('CAP_SCREW', 5);
      final id = await repo.createB2BOrder(
        customerId: customer,
        items: lines(7),
        deliveryDate: delivery(),
      );
      await repo.confirmB2BOrder(id);
      await repo.cancelB2BOrder(id);
      expect((await repo.itemByCode('FG_350'))!.currentQuantity, 2);
      expect((await repo.itemByCode('FG_350'))!.reservedQuantity, 0);
      expect((await repo.itemByCode('PET_350'))!.currentQuantity, 5);
      expect((await repo.itemByCode('PET_350'))!.reservedQuantity, 0);
      expect(await db.query('b2b_material_allocations'), isEmpty);
    },
  );

  test(
    'missing recipes, early delivery, unknown customer and invalid quantities are rejected',
    () async {
      final missing = await repo.precheckB2BOrder([
        {'item_code': 'FG_600', 'quantity': 1.0},
      ]);
      expect(missing.missingRecipes, isNotEmpty);
      await repo.receive('PET_350', 1);
      await repo.receive('CAP_SCREW', 1);
      final id = await repo.createB2BOrder(
        customerId: customer,
        items: lines(1),
        deliveryDate: DateTime.now(),
      );
      await expectLater(repo.confirmB2BOrder(id), throwsException);
      await expectLater(
        repo.createB2BOrder(customerId: 99999, items: lines(1)),
        throwsException,
      );
      await expectLater(
        repo.createB2BOrder(customerId: customer, items: lines(-1)),
        throwsException,
      );
      await expectLater(
        repo.createB2BOrder(customerId: customer, items: lines(double.nan)),
        throwsException,
      );
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      await expectLater(
        db.insert('b2b_orders', {
          'customer_id': 9999,
          'status': 'draft',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        (await repo.b2bCustomers(search: '099')).single['name'],
        'Restaurant',
      );
    },
  );

  test(
    'purchase-price history uses immutable dated receipt prices, not current item cost',
    () async {
      expect((await repo.dashboardStats()).first['purchase_prices'], isEmpty);
      await repo.recordPurchaseReceipt(
        itemCode: 'PET_600',
        quantity: 100,
        unitPrice: 1.25,
        supplier: 'Supplier A',
        reference: 'INV-001',
        purchasedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await repo.recordPurchaseReceipt(
        itemCode: 'PET_600',
        quantity: 50,
        unitPrice: 1.50,
        supplier: 'Supplier B',
        reference: 'INV-002',
        purchasedAt: DateTime.now(),
      );
      await db.update(
        'items',
        {'unit_cost': 9},
        where: 'code = ?',
        whereArgs: ['PET_600'],
      );
      final prices =
          (await repo.dashboardStats()).first['purchase_prices'] as List;
      expect(prices.map((r) => r['unit_price']).toList(), [1.25, 1.50]);
      expect(
        (await repo.dashboardStats(days: 1)).first['purchase_prices'] as List,
        hasLength(1),
      );
      expect((await repo.itemByCode('PET_600'))!.currentQuantity, 150);
      expect((await repo.purchaseReceipts()).first['reference'], 'INV-002');
      await expectLater(
        repo.recordPurchaseReceipt(
          itemCode: 'PET_600',
          quantity: 1,
          unitPrice: 2,
          supplier: 'A',
          purchasedAt: DateTime.now().add(const Duration(days: 1)),
        ),
        throwsException,
      );
    },
  );
  test(
    'shared material demand across products is checked before any reservation',
    () async {
      await repo.saveRecipe(
        productCode: 'FG_600',
        materials: [
          {'material_code': 'CAP_SCREW', 'quantity': 1.0},
        ],
        productionLeadDays: 1,
      );
      await repo.receive('PET_350', 2);
      await repo.receive('CAP_SCREW', 3);
      final products = <Map<String, Object?>>[
        {'item_code': 'FG_350', 'quantity': 2.0, 'unit_price': 5.0},
        {'item_code': 'FG_600', 'quantity': 2.0, 'unit_price': 6.0},
      ];
      final plan = await repo.precheckB2BOrder(
        products,
        deliveryDate: delivery(),
      );
      expect(
        plan.materials
            .firstWhere((m) => m.material.code == 'CAP_SCREW')
            .requiredQuantity,
        4,
      );
      expect(
        plan.materials
            .firstWhere((m) => m.material.code == 'CAP_SCREW')
            .shortage,
        1,
      );
      final id = await repo.createB2BOrder(
        customerId: customer,
        items: products,
        deliveryDate: delivery(),
      );
      await expectLater(repo.confirmB2BOrder(id), throwsException);
      expect((await repo.itemByCode('CAP_SCREW'))!.reservedQuantity, 0);
      expect(await db.query('b2b_material_allocations'), isEmpty);
    },
  );
}
