import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_world/data/app_db.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('v7 upgrade preserves users and confirmed stock allocations', () async {
    final folder = await Directory.systemTemp.createTemp(
      'water_world_upgrade_',
    );
    final path = '${folder.path}/test.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE items (code TEXT PRIMARY KEY, name TEXT NOT NULL, item_type TEXT, current_quantity REAL DEFAULT 0, reserved_quantity REAL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE b2b_customers (id INTEGER PRIMARY KEY, name TEXT)',
          );
          await db.execute(
            'CREATE TABLE b2b_orders (id INTEGER PRIMARY KEY, customer_id INTEGER, status TEXT, notes TEXT, created_at TEXT, updated_at TEXT)',
          );
          await db.execute(
            'CREATE TABLE b2b_order_lines (id INTEGER PRIMARY KEY, order_id INTEGER, item_code TEXT, quantity REAL, unit_price REAL)',
          );
          await db.execute(
            'CREATE TABLE local_users (id INTEGER PRIMARY KEY, username TEXT, display_name TEXT, role TEXT, pin_hash TEXT, pin_salt TEXT, active INTEGER, created_at TEXT)',
          );
          await db.insert('items', {
            'code': 'FG_350',
            'name': '350 ml',
            'item_type': 'finished',
            'current_quantity': 10,
            'reserved_quantity': 3,
          });
          await db.insert('b2b_customers', {
            'id': 1,
            'name': 'Existing customer',
          });
          await db.insert('b2b_orders', {
            'id': 1,
            'customer_id': 1,
            'status': 'confirmed',
            'notes': '',
            'created_at': '2026-10-17',
            'updated_at': '2026-10-17',
          });
          await db.insert('b2b_order_lines', {
            'id': 1,
            'order_id': 1,
            'item_code': 'FG_350',
            'quantity': 3,
            'unit_price': 5,
          });
          await db.insert('local_users', {
            'id': 7,
            'username': 'admin',
            'display_name': 'Admin',
            'role': 'Manager',
            'pin_hash': 'preserve-this-hash',
            'pin_salt': 'preserve-this-salt',
            'active': 1,
            'created_at': '2026-10-17',
          });
        },
      ),
    );
    await legacy.close();
    final appDb = AppDb.forTesting(factory: databaseFactoryFfi, path: path);
    try {
      final db = await appDb.database;
      expect(await db.getVersion(), 8);
      expect(
        (await db.query('b2b_order_lines')).single['reserved_finished'],
        3,
      );
      expect(
        (await db.query('local_users')).single['pin_hash'],
        'preserve-this-hash',
      );
      expect((await db.query('local_users')).single['id'], 7);
      expect((await db.query('items')).single['reserved_quantity'], 3);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
    } finally {
      await appDb.close();
      await folder.delete(recursive: true);
    }
  });
}
