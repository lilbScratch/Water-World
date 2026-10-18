import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_world/data/app_db.dart';
import 'package:water_world/data/stock_repository.dart';
import 'package:water_world/providers/auth_provider.dart';
import 'package:water_world/providers/inventory_provider.dart';
import 'package:water_world/screens/executive_dashboard_page.dart';
import 'package:water_world/screens/main_shell.dart';

void main() {
  late Directory folder;
  late AppDb db;
  late InventoryProvider inventory;
  late AuthProvider auth;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('water_world_access_');
    db = AppDb.forTesting(
      factory: databaseFactoryFfi,
      path: '${folder.path}/test.db',
    );
    await db.database;
    inventory = InventoryProvider(repo: StockRepository(appDb: db));
    auth = AuthProvider(appDb: db)..loading = false;
  });
  tearDown(() async {
    inventory.dispose();
    auth.dispose();
    await db.close();
    await folder.delete(recursive: true);
  });
  for (final role in ['User', 'Custom role', 'Production', 'Purchasing']) {
    testWidgets(
      '$role can use operational pages but cannot access dashboard or roles',
      (tester) async {
        auth.currentUser = AppUser(
          id: 2,
          username: 'member',
          displayName: 'Member',
          role: role,
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: inventory),
            ],
            child: const MaterialApp(home: MainShell()),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ExecutiveDashboardPage), findsNothing);
        for (final label in [
          'คลังสินค้า',
          'แจ้งเตือน',
          'คำสั่งซื้อขายส่ง',
          'ประวัติ',
        ]) {
          expect(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
        expect(auth.canManageInventory, isTrue);
        expect(auth.canManageOrders, isTrue);
        await expectLater(auth.users(), throwsException);
        await expectLater(auth.setUserRole(1, 'Manager'), throwsException);
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        expect(find.text('จัดการบัญชีผู้ใช้'), findsNothing);
        expect(find.text('สูตรการผลิต'), findsOneWidget);
        expect(find.text('ใบรับสินค้าจากการซื้อ'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
