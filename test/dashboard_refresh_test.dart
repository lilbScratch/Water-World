import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_world/data/app_db.dart';
import 'package:water_world/data/stock_repository.dart';
import 'package:water_world/providers/inventory_provider.dart';
import 'package:water_world/providers/auth_provider.dart';
import 'package:water_world/screens/auth_gate.dart';
import 'package:water_world/screens/executive_dashboard_page.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  testWidgets('dashboard reloads SQL totals when inventory Provider changes', (
    tester,
  ) async {
    late Directory folder;
    late AppDb appDb;
    late StockRepository repo;
    late InventoryProvider inventory;
    late AuthProvider auth;
    await tester.runAsync(() async {
      folder = await Directory.systemTemp.createTemp('water_world_dashboard_');
      appDb = AppDb.forTesting(
        factory: databaseFactoryFfi,
        path: '${folder.path}/test.db',
      );
      repo = StockRepository(appDb: appDb);
      inventory = InventoryProvider(repo: repo);
      auth = AuthProvider(appDb: appDb);
      await auth.initialize();
      await auth.signIn('admin', '123456');
      final db = await appDb.database;
      await db.update(
        'items',
        {'unit_cost': 2.0},
        where: 'code = ?',
        whereArgs: ['PET_350'],
      );
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: inventory),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(home: ExecutiveDashboardPage()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    expect(find.text('20.00'), findsNothing);
    await tester.runAsync(() async {
      await repo.receive('PET_350', 10);
      await repo.receive('FG_350', 4);
      await inventory.refresh();
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    expect(find.text('20.00'), findsOneWidget);
    await tester.tap(find.byTooltip('รีเฟรชภาพรวม'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('20.00'), findsOneWidget);
    expect(find.textContaining('4.00 พร้อมใช้'), findsOneWidget);
    await tester.tap(find.text('จัดการบัญชีผู้ใช้'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminUsersPage), findsOneWidget);
    expect(find.textContaining('admin • ผู้จัดการ'), findsOneWidget);
    await tester.tap(find.byTooltip('เปลี่ยนบทบาท').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final closeAction in ['save', 'back', 'outside']) {
      await tester.tap(find.byTooltip('เปลี่ยนบทบาท').first);
      await tester.pumpAndSettle();
      if (closeAction == 'save') {
        await tester.tap(find.text('บันทึกบทบาท'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
      } else if (closeAction == 'back') {
        await tester.pageBack();
      } else {
        await tester.tapAt(const Offset(10, 10));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AdminUsersPage), findsOneWidget);
    }
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    inventory.dispose();
    auth.dispose();
    await tester.runAsync(() async {
      await appDb.close();
      await folder.delete(recursive: true);
    });
  });
}
