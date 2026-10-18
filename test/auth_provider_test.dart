import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:water_world/data/app_db.dart';
import 'package:water_world/providers/auth_provider.dart';

void main() {
  late Directory folder;
  late AppDb db;
  late AuthProvider auth;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('water_world_auth_');
    db = AppDb.forTesting(
      factory: databaseFactoryFfi,
      path: '${folder.path}/test.db',
    );
    auth = AuthProvider(appDb: db);
    await auth.initialize();
  });
  tearDown(() async {
    auth.dispose();
    await db.close();
    await folder.delete(recursive: true);
  });
  test(
    'fresh database seeds the requested Manager with a hashed six-character password',
    () async {
      await expectLater(auth.signIn('admin', '1234'), throwsException);
      await auth.signIn('admin', '123456');
      expect(auth.isManager, isTrue);
      await auth.setUserRole(1, 'ผู้จัดการ');
      expect(auth.currentUser!.role, 'Manager');
      final database = await db.database;
      final row = (await database.query('local_users')).single;
      expect(row['id'], 1);
      expect(row['pin_hash'], isNot('123456'));
      expect(row['pin_salt'], isNotEmpty);
      await expectLater(auth.setUserRole(1, 'Production'), throwsException);
    },
  );
  test(
    'registration signs in immediately as User and cannot assign roles',
    () async {
      await auth.registerUser(
        username: 'Member',
        displayName: 'Member',
        pin: '654321',
      );
      await auth.signIn('member', '654321');
      expect(auth.currentUser!.role, 'User');
      expect(auth.isManager, isFalse);
      expect(auth.canManageInventory, isTrue);
      expect(auth.canManageOrders, isTrue);
      await expectLater(
        auth.setUserRole(auth.currentUser!.id, 'Manager'),
        throwsException,
      );
      await expectLater(
        auth.registerUser(
          username: 'MEMBER',
          displayName: 'Duplicate',
          pin: '654321',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('ชื่อผู้ใช้นี้มีอยู่แล้ว'),
          ),
        ),
      );
      await expectLater(
        auth.registerUser(username: 'short', displayName: 'Short', pin: '123'),
        throwsException,
      );
    },
  );
  test(
    'Manager designates operational or custom roles and can disable another account',
    () async {
      await auth.registerUser(
        username: 'staff',
        displayName: 'Staff',
        pin: '654321',
      );
      await auth.signIn('admin', '123456');
      final staff = (await auth.users()).firstWhere(
        (r) => r['username'] == 'staff',
      );
      final id = (staff['id'] as num).toInt();
      await auth.setUserRole(id, 'ฝ่ายผลิต');
      auth.signOut();
      await auth.signIn('staff', '654321');
      expect(auth.canManageInventory, isTrue);
      expect(auth.canManageOrders, isTrue);
      auth.signOut();
      await auth.signIn('admin', '123456');
      await auth.setUserRole(id, 'ฝ่ายจัดซื้อ');
      auth.signOut();
      await auth.signIn('staff', '654321');
      expect(auth.canManageOrders, isTrue);
      expect(auth.canManageInventory, isTrue);
      auth.signOut();
      await auth.signIn('admin', '123456');
      await auth.setUserRole(id, 'Driver');
      await auth.setUserActive(id, false);
      auth.signOut();
      await expectLater(auth.signIn('staff', '654321'), throwsException);
    },
  );
}
