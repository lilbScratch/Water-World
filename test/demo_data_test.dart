import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_world/data/app_db.dart';
import 'package:water_world/data/stock_repository.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'presentation data creates coherent sales, buys, and daily chart',
    () async {
      final folder = await Directory.systemTemp.createTemp('water_world_demo_');
      final appDb = AppDb.forTesting(
        factory: databaseFactoryFfi,
        path: '${folder.path}/demo.db',
      );
      final repo = StockRepository(appDb: appDb);
      try {
        await repo.ensurePresentationData();
        final db = await appDb.database;
        final sales = await db.rawQuery(
          "SELECT COUNT(*) AS n FROM b2b_orders WHERE status='fulfilled'",
        );
        final purchases = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM purchase_receipts',
        );
        expect(sales.single['n'], 6);
        expect(purchases.single['n'], 6);
        expect((await repo.itemByCode('FG_350'))!.currentQuantity, 255);
        expect((await repo.itemByCode('PET_350'))!.currentQuantity, 1900);

        final dashboard = await repo.dashboardStats(days: 7);
        final summary = dashboard.first['summary'] as Map<String, Object?>;
        expect((summary['period_revenue'] as num).toDouble(), 3417.5);
        final chart = (dashboard.first['cash_flow'] as List)
            .cast<Map<String, Object?>>();
        expect(chart, hasLength(7));
        expect(chart.where((day) => (day['sales'] as num) > 0), hasLength(6));
        expect(
          chart.where((day) => (day['purchases'] as num) > 0),
          hasLength(6),
        );

        await repo.ensurePresentationData();
        expect(
          (await db.rawQuery(
            'SELECT COUNT(*) AS n FROM b2b_orders',
          )).single['n'],
          6,
        );
        expect((await repo.itemByCode('FG_350'))!.currentQuantity, 255);
      } finally {
        await appDb.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
