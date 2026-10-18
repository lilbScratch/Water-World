import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_db.dart';

class AppUser {
  final int id;
  final String username;
  final String displayName;
  final String role;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, Object?> row) => AppUser(
    id: (row['id'] as num).toInt(),
    username: row['username'] as String,
    displayName: row['display_name'] as String,
    role: row['role'] as String,
  );
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({AppDb? appDb}) : _appDb = appDb ?? AppDb.instance;
  final AppDb _appDb;
  static const _defaultManagerUsername = 'admin';
  static const _defaultManagerPin = '123456';

  AppUser? currentUser;
  bool loading = true;
  int pendingSync = 0;

  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );
  static const _syncUrl = String.fromEnvironment('WATER_WORLD_SYNC_URL');
  static const _syncKey = String.fromEnvironment('WATER_WORLD_SYNC_KEY');

  bool get hasConfiguredSync => _syncUrl.isNotEmpty && _syncKey.isNotEmpty;
  bool get hasSession => currentUser != null;
  String get currentRole => currentUser?.role.trim().toLowerCase() ?? '';
  bool get isManager => currentRole == 'manager' || currentRole == 'admin';
  bool get isAdmin => isManager;
  bool get canManageInventory => hasSession;
  bool get canManageOrders => hasSession;

  Future<void> initialize() async {
    if (await userCount == 0) {
      await _insertUser(
        username: _defaultManagerUsername,
        displayName: 'Admin',
        role: 'Manager',
        pin: _defaultManagerPin,
      );
    }
    final db = await _appDb.database;
    // Keep the requested built-in Manager account and allow existing users
    // created under the old approval flow to sign in.
    await db.update(
      'local_users',
      {'role': 'Manager'},
      where: 'lower(username) = ?',
      whereArgs: [_defaultManagerUsername],
    );
    await db.update(
      'local_users',
      {'role': 'User'},
      where: 'lower(role) = ?',
      whereArgs: ['unverified'],
    );
    pendingSync =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE synced_at IS NULL',
          ),
        ) ??
        0;
    loading = false;
    notifyListeners();
  }

  Future<int> get userCount async {
    final db = await _appDb.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM local_users'),
        ) ??
        0;
  }

  Future<bool> get hasUsers async => await userCount > 0;

  Future<void> registerUser({
    required String username,
    required String displayName,
    required String pin,
  }) async {
    await _insertUser(
      username: username,
      displayName: displayName,
      role: 'User',
      pin: pin,
    );
  }

  Future<void> createInitialManager({
    required String username,
    required String displayName,
    required String pin,
  }) async {
    if (await userCount != 0) {
      throw Exception('มีบัญชีผู้จัดการอยู่แล้ว');
    }
    await _insertUser(
      username: username,
      displayName: displayName,
      role: 'Manager',
      pin: pin,
    );
  }

  Future<void> createUser({
    required String username,
    required String displayName,
    required String role,
    required String pin,
  }) async {
    if (!isManager) throw Exception('เฉพาะผู้จัดการเท่านั้นที่เพิ่มบัญชีได้');
    await _insertUser(
      username: username,
      displayName: displayName,
      role: role,
      pin: pin,
    );
  }

  Future<void> _insertUser({
    required String username,
    required String displayName,
    required String role,
    required String pin,
  }) async {
    if (username.trim().isEmpty || displayName.trim().isEmpty) {
      throw Exception('กรุณาระบุชื่อที่แสดงและชื่อผู้ใช้');
    }
    if (role.trim().isEmpty) throw Exception('กรุณาระบุบทบาท');
    if (pin.length < 6) {
      throw Exception('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }
    final saltBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final salt = base64UrlEncode(saltBytes);
    final derivedKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: saltBytes,
    );
    final hash = base64UrlEncode(await derivedKey.extractBytes());
    final db = await _appDb.database;
    try {
      await db.insert('local_users', {
        'username': username.trim().toLowerCase(),
        'display_name': displayName.trim(),
        'role': username.trim().toLowerCase() == _defaultManagerUsername
            ? 'Manager'
            : _normalizeRole(role),
        'pin_hash': hash,
        'pin_salt': salt,
        'active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw Exception('ชื่อผู้ใช้นี้มีอยู่แล้ว กรุณาใช้ชื่ออื่น');
      }
      rethrow;
    }
  }

  Future<void> signIn(String username, String pin) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'local_users',
      where: 'username = ?',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
    final row = rows.first;
    final saltBytes = base64Url.decode(row['pin_salt'] as String);
    final derivedKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: saltBytes,
    );
    final hash = base64UrlEncode(await derivedKey.extractBytes());
    if (hash != row['pin_hash']) {
      throw Exception('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
    }
    if ((row['active'] as num).toInt() != 1) {
      throw Exception('บัญชีนี้ถูกระงับการใช้งาน กรุณาติดต่อผู้จัดการ');
    }
    currentUser = AppUser.fromMap(row);
    notifyListeners();
  }

  void signOut() {
    currentUser = null;
    notifyListeners();
  }

  Future<List<Map<String, Object?>>> users() async {
    if (!isManager) {
      throw Exception('เฉพาะผู้จัดการเท่านั้นที่ดูบัญชีผู้ใช้ได้');
    }
    final db = await _appDb.database;
    return db.query(
      'local_users',
      columns: ['id', 'username', 'display_name', 'role', 'active'],
      orderBy: 'display_name',
    );
  }

  Future<void> setUserActive(int id, bool active) async {
    if (!isManager) {
      throw Exception('เฉพาะผู้จัดการเท่านั้นที่เปลี่ยนสิทธิ์การเข้าใช้งานได้');
    }
    if (currentUser?.id == id && !active) {
      throw Exception('ไม่สามารถระงับบัญชีที่กำลังใช้งานอยู่ได้');
    }
    final db = await _appDb.database;
    if (!active) {
      final admins =
          Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM local_users WHERE lower(role) IN ('manager', 'admin') AND active = 1",
            ),
          ) ??
          0;
      final target = await db.query(
        'local_users',
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (target.isNotEmpty &&
          [
            'manager',
            'admin',
          ].contains(target.first['role'].toString().toLowerCase()) &&
          admins <= 1) {
        throw Exception('ต้องมีบัญชีผู้จัดการที่ใช้งานได้อย่างน้อย 1 บัญชี');
      }
    }
    await db.update(
      'local_users',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setUserRole(int id, String role) async {
    if (!isManager) throw Exception('เฉพาะผู้จัดการเท่านั้นที่เปลี่ยนบทบาทได้');
    final normalizedRole = _normalizeRole(role);
    if (normalizedRole.isEmpty) throw Exception('กรุณาระบุบทบาท');
    if (currentUser?.id == id &&
        !['manager', 'admin'].contains(normalizedRole.toLowerCase())) {
      throw Exception('ไม่สามารถนำบทบาทผู้จัดการออกจากบัญชีที่กำลังใช้งานได้');
    }

    final db = await _appDb.database;
    final targetUser = await db.query(
      'local_users',
      columns: ['username'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (targetUser.isEmpty) throw Exception('ไม่พบบัญชีผู้ใช้');
    if (targetUser.first['username'].toString().toLowerCase() ==
            _defaultManagerUsername &&
        !['manager', 'admin'].contains(normalizedRole.toLowerCase())) {
      throw Exception('บัญชี admin ต้องคงบทบาทผู้จัดการ');
    }
    await db.transaction((txn) async {
      final target = await txn.query(
        'local_users',
        columns: ['role', 'active'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (target.isEmpty) throw Exception('ไม่พบบัญชีผู้ใช้');

      final oldRole = target.first['role'].toString().toLowerCase();
      final nextRole = normalizedRole.toLowerCase();
      if ((oldRole == 'manager' || oldRole == 'admin') &&
          nextRole != 'manager' &&
          nextRole != 'admin' &&
          (target.first['active'] as num).toInt() == 1) {
        final managers =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                "SELECT COUNT(*) FROM local_users WHERE lower(role) IN ('manager', 'admin') AND active = 1",
              ),
            ) ??
            0;
        if (managers <= 1) {
          throw Exception('ต้องมีบัญชีผู้จัดการที่ใช้งานได้อย่างน้อย 1 บัญชี');
        }
      }

      await txn.update(
        'local_users',
        {'role': normalizedRole},
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    if (currentUser?.id == id) {
      currentUser = AppUser(
        id: currentUser!.id,
        username: currentUser!.username,
        displayName: currentUser!.displayName,
        role: normalizedRole,
      );
      notifyListeners();
    }
  }

  String _normalizeRole(String role) {
    final trimmed = role.trim();
    switch (trimmed.toLowerCase()) {
      case 'admin':
      case 'manager':
      case 'ผู้จัดการ':
        return 'Manager';
      case 'user':
      case 'ผู้ใช้งานทั่วไป':
      case 'unverified':
        return 'User';
      case 'production':
      case 'ฝ่ายผลิต':
        return 'Production';
      case 'purchasing':
      case 'ฝ่ายจัดซื้อ':
        return 'Purchasing';
      default:
        return trimmed;
    }
  }

  Future<void> refreshSyncCount() async {
    final db = await _appDb.database;
    pendingSync =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_queue WHERE synced_at IS NULL',
          ),
        ) ??
        0;
    notifyListeners();
  }
}
