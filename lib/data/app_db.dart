import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._internal() : _factory = null, _customPath = null;

  /// สร้างฐานข้อมูลแยกสำหรับการทดสอบ
  AppDb.forTesting({required DatabaseFactory factory, required String path})
    : _factory = factory,
      _customPath = path;

  /// ฐานข้อมูลหลักของแอป
  static final AppDb instance = AppDb._internal();

  final DatabaseFactory? _factory;
  final String? _customPath;

  Database? _database;

  static const String _databaseName = 'water_world.db';
  static const int _databaseVersion = 8;

  // --------------------------------------------------
  // DATABASE
  // --------------------------------------------------

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final String path;

    if (_customPath != null) {
      path = _customPath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _databaseName);
    }

    print('WATER WORLD DB PATH: $path');

    final factory = _factory ?? databaseFactory;

    _database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _createSchema(db);
          if (oldVersion < 6) {
            await _migrateFlexibleUserRoles(db);
          }
          if (oldVersion < 7) {
            await _migrateUserAccessRoles(db);
          }
          if (oldVersion < 8) {
            await _ensurePlanningColumns(db);
            await db.execute('''
              UPDATE b2b_order_lines SET reserved_finished = quantity
              WHERE order_id IN (SELECT id FROM b2b_orders WHERE status = 'confirmed')
            ''');
            await db.execute(
              "UPDATE b2b_orders SET fulfilled_at = updated_at WHERE status = 'fulfilled'",
            );
          }
        },
        onOpen: (db) async {
          await _ensureAllColumns(db);
          await _ensurePlanningColumns(db);
        },
      ),
    );

    await _createSchema(_database!);
    await _ensureAllColumns(_database!);
    await _seed(_database!);

    return _database!;
  }

  /// ปิดฐานข้อมูล ใช้สำหรับการทดสอบหรือปิดการใช้งาน
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }

    _database = null;
  }

  // --------------------------------------------------
  // CREATE TABLES
  // --------------------------------------------------

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'raw',
        unit TEXT NOT NULL DEFAULT 'ชิ้น',
        current_quantity REAL NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL DEFAULT 0,
        min_quantity REAL NOT NULL DEFAULT 0,
        safety_stock REAL NOT NULL DEFAULT 0,
        reserved_quantity REAL NOT NULL DEFAULT 0,
        lead_time_days INTEGER NOT NULL DEFAULT 1,
        target_days REAL NOT NULL DEFAULT 7,
        service_level_z REAL NOT NULL DEFAULT 1.65
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_code TEXT NOT NULL,
        material_code TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_code TEXT,
        product_name TEXT,
        quantity REAL NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_code TEXT,
        item_name TEXT,
        tx_type TEXT NOT NULL DEFAULT '',
        quantity REAL NOT NULL DEFAULT 0,
        balance_after REAL NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_code TEXT,
        item_name TEXT,
        quantity REAL NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL DEFAULT 0,
        total_cost REAL NOT NULL DEFAULT 0,
        items_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT,
        expected_date TEXT,
        received_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS b2b_customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS b2b_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES b2b_customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS b2b_order_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        item_code TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(order_id) REFERENCES b2b_orders(id) ON DELETE CASCADE,
        FOREIGN KEY(item_code) REFERENCES items(code)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'User',
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS b2b_material_allocations (
        order_id INTEGER NOT NULL REFERENCES b2b_orders(id) ON DELETE CASCADE,
        product_code TEXT NOT NULL REFERENCES items(code),
        material_code TEXT NOT NULL REFERENCES items(code),
        quantity REAL NOT NULL CHECK(quantity > 0),
        PRIMARY KEY(order_id, product_code, material_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_code TEXT NOT NULL REFERENCES items(code),
        quantity REAL NOT NULL CHECK(quantity > 0),
        unit_price REAL NOT NULL CHECK(unit_price >= 0),
        supplier TEXT NOT NULL,
        reference TEXT NOT NULL DEFAULT '',
        purchased_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS receipt_item_date ON purchase_receipts(item_code, purchased_at)',
    );
  }

  Future<void> _ensurePlanningColumns(DatabaseExecutor db) async {
    await _ensureColumn(
      db,
      'items',
      'production_lead_days',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(db, 'b2b_orders', 'delivery_date', 'TEXT');
    await _ensureColumn(db, 'b2b_orders', 'confirmed_at', 'TEXT');
    await _ensureColumn(db, 'b2b_orders', 'fulfilled_at', 'TEXT');
    await _ensureColumn(
      db,
      'b2b_order_lines',
      'reserved_finished',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'b2b_order_lines',
      'production_quantity',
      'REAL NOT NULL DEFAULT 0',
    );
  }

  Future<void> _migrateFlexibleUserRoles(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info("local_users")');
    if (columns.isEmpty) return;

    await db.execute('ALTER TABLE local_users RENAME TO local_users_v5');
    await db.execute('''
      CREATE TABLE local_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'User',
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO local_users
        (id, username, display_name, role, pin_hash, pin_salt, active, created_at)
      SELECT id, username, display_name,
        CASE WHEN lower(role) = 'admin' THEN 'Manager' ELSE role END,
        pin_hash, pin_salt, active, created_at
      FROM local_users_v5
    ''');
    await db.execute('DROP TABLE local_users_v5');
  }

  Future<void> _migrateUserAccessRoles(DatabaseExecutor db) async {
    await db.execute(
      "UPDATE local_users SET role = 'User' WHERE lower(role) = 'unverified'",
    );
    await db.execute(
      "UPDATE local_users SET role = 'Manager' WHERE lower(username) = 'admin'",
    );
  }

  // --------------------------------------------------
  // ENSURE COLUMNS
  // --------------------------------------------------

  Future<void> _ensureColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info("$table")');

    final exists = columns.any((row) => row['name']?.toString() == column);

    if (!exists) {
      await db.execute('ALTER TABLE "$table" ADD COLUMN "$column" $definition');

      print('DB MIGRATION: added $table.$column');
    }
  }

  Future<void> _ensureAllColumns(DatabaseExecutor db) async {
    // items
    await _ensureColumn(db, 'items', 'code', 'TEXT');
    await _ensureColumn(db, 'items', 'name', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(
      db,
      'items',
      'item_type',
      "TEXT NOT NULL DEFAULT 'raw'",
    );
    await _ensureColumn(db, 'items', 'unit', "TEXT NOT NULL DEFAULT 'ชิ้น'");
    await _ensureColumn(
      db,
      'items',
      'current_quantity',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(db, 'items', 'unit_cost', 'REAL NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'items', 'min_quantity', 'REAL NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'items', 'safety_stock', 'REAL NOT NULL DEFAULT 0');
    await _ensureColumn(
      db,
      'items',
      'reserved_quantity',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'items',
      'lead_time_days',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(db, 'items', 'target_days', 'REAL NOT NULL DEFAULT 7');
    await _ensureColumn(
      db,
      'items',
      'service_level_z',
      'REAL NOT NULL DEFAULT 1.65',
    );

    // stock_transactions
    await _ensureColumn(db, 'stock_transactions', 'item_code', 'TEXT');
    await _ensureColumn(db, 'stock_transactions', 'item_name', 'TEXT');
    await _ensureColumn(
      db,
      'stock_transactions',
      'tx_type',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'stock_transactions',
      'quantity',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'stock_transactions',
      'balance_after',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(db, 'stock_transactions', 'note', 'TEXT');
    await _ensureColumn(db, 'stock_transactions', 'created_at', 'TEXT');

    // recipes
    await _ensureColumn(db, 'recipes', 'product_code', 'TEXT');
    await _ensureColumn(db, 'recipes', 'material_code', 'TEXT');
    await _ensureColumn(db, 'recipes', 'quantity', 'REAL NOT NULL DEFAULT 0');

    // production_batches
    await _ensureColumn(db, 'production_batches', 'product_code', 'TEXT');
    await _ensureColumn(db, 'production_batches', 'product_name', 'TEXT');
    await _ensureColumn(
      db,
      'production_batches',
      'quantity',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(db, 'production_batches', 'note', 'TEXT');
    await _ensureColumn(db, 'production_batches', 'created_at', 'TEXT');

    // purchase_orders
    await _ensureColumn(db, 'purchase_orders', 'item_code', 'TEXT');
    await _ensureColumn(db, 'purchase_orders', 'item_name', 'TEXT');
    await _ensureColumn(
      db,
      'purchase_orders',
      'quantity',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'purchase_orders',
      'unit_cost',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'purchase_orders',
      'total_cost',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'purchase_orders',
      'items_json',
      "TEXT NOT NULL DEFAULT '[]'",
    );
    await _ensureColumn(
      db,
      'purchase_orders',
      'status',
      "TEXT NOT NULL DEFAULT 'pending'",
    );
    await _ensureColumn(db, 'purchase_orders', 'created_at', 'TEXT');
    await _ensureColumn(db, 'purchase_orders', 'expected_date', 'TEXT');
    await _ensureColumn(db, 'purchase_orders', 'received_at', 'TEXT');

    final columns = await db.rawQuery('PRAGMA table_info(stock_transactions)');

    print('=== STOCK TRANSACTIONS COLUMNS ===');
    for (final column in columns) {
      print(column['name']);
    }
    print('==================================');
  }

  // --------------------------------------------------
  // SEED DATA
  // --------------------------------------------------

  Future<void> _seed(DatabaseExecutor db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM items');

    final count = (result.first['total'] as num?)?.toInt() ?? 0;

    // ถ้ามีสินค้าแล้ว ไม่เขียนทับข้อมูลเดิม
    if (count > 0) return;

    final batch = db.batch();

    final items = [
      {
        'code': 'PET_350',
        'name': 'ขวดน้ำ 350 ml',
        'item_type': 'raw',
        'unit': 'ขวด',
      },
      {
        'code': 'PET_600',
        'name': 'ขวดน้ำ 600 ml',
        'item_type': 'raw',
        'unit': 'ขวด',
      },
      {
        'code': 'PET_1500',
        'name': 'ขวดน้ำ 1500 ml',
        'item_type': 'raw',
        'unit': 'ขวด',
      },
      {'code': 'CAP_SCREW', 'name': 'ฝาขวด', 'item_type': 'raw', 'unit': 'ฝา'},
      {
        'code': 'PVC_FILM',
        'name': 'ฟิล์มหด PVC',
        'item_type': 'raw',
        'unit': 'ม้วน',
      },
      {
        'code': 'PE_FILM',
        'name': 'ฟิล์มหุ้มแพ็ก PE',
        'item_type': 'raw',
        'unit': 'ม้วน',
      },
      {
        'code': 'FG_350',
        'name': 'น้ำดื่ม 350 ml',
        'item_type': 'finished',
        'unit': 'ขวด',
      },
      {
        'code': 'FG_600',
        'name': 'น้ำดื่ม 600 ml',
        'item_type': 'finished',
        'unit': 'ขวด',
      },
      {
        'code': 'FG_1500',
        'name': 'น้ำดื่ม 1500 ml',
        'item_type': 'finished',
        'unit': 'ขวด',
      },
    ];

    for (final item in items) {
      batch.insert('items', {
        ...item,
        'current_quantity': 0,
        'unit_cost': 0,
        'min_quantity': 0,
        'safety_stock': 0,
        'reserved_quantity': 0,
        'lead_time_days': 1,
        'target_days': 7,
        'service_level_z': 1.65,
      });
    }

    await batch.commit(noResult: true);
  }
}
