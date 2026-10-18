import '../thai_labels.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'main_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FutureBuilder<bool>(
      future: auth.hasUsers,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == false) return const FirstAdminPage();
        if (!auth.hasSession) return const SignInPage();
        return const MainShell();
      },
    );
  }
}

class FirstAdminPage extends StatefulWidget {
  const FirstAdminPage({super.key});

  @override
  State<FirstAdminPage> createState() => _FirstAdminPageState();
}

class _FirstAdminPageState extends State<FirstAdminPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await auth.createInitialManager(
        username: _username.text,
        displayName: _name.text,
        pin: _pin.text,
      );
      await auth.signIn(_username.text, _pin.text);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'ตั้งค่า Water World',
    subtitle: 'สร้างบัญชีผู้จัดการคนแรกบนอุปกรณ์นี้',
    child: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
            validator: _required,
          ),
          TextFormField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
            validator: _required,
          ),
          TextFormField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)',
            ),
            validator: (v) => (v?.length ?? 0) < 6
                ? 'กรุณาใช้รหัสผ่านอย่างน้อย 6 ตัวอักษร'
                : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(_saving ? 'กำลังสร้างบัญชี…' : 'สร้างบัญชีผู้จัดการ'),
            ),
          ),
        ],
      ),
    ),
  );
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _username = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().signIn(_username.text, _pin.text);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final registered = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RegisterPage()));
    if (registered == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สมัครสมาชิกสำเร็จ สามารถเข้าสู่ระบบได้แล้ว'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Water World',
    subtitle: 'เข้าสู่ระบบด้วยบัญชีผู้ใช้ของคุณ',
    child: Column(
      children: [
        TextField(
          controller: _username,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
        ),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _signIn(),
          decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _signIn,
            child: Text(_busy ? 'กำลังเข้าสู่ระบบ…' : 'เข้าสู่ระบบ'),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _register,
          child: const Text('สมัครสมาชิก'),
        ),
      ],
    ),
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().registerUser(
        username: _username.text,
        displayName: _name.text,
        pin: _pin.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'สมัครสมาชิก',
    subtitle:
        'สมัครสมาชิกเพื่อใช้งาน Water World โดยเริ่มต้นด้วยบทบาทผู้ใช้งานทั่วไป',
    child: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
            validator: _required,
          ),
          TextFormField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
            validator: _required,
          ),
          TextFormField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)',
            ),
            validator: (value) => (value?.length ?? 0) < 6
                ? 'กรุณาใช้รหัสผ่านอย่างน้อย 6 ตัวอักษร'
                : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _register,
              child: Text(_busy ? 'กำลังสร้างบัญชี…' : 'สมัครสมาชิก'),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('กลับไปหน้าเข้าสู่ระบบ'),
          ),
        ],
      ),
    ),
  );
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<Map<String, Object?>>> _users;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _users = context.read<AuthProvider>().users();
  }

  Future<void> _addUser() async {
    final auth = context.read<AuthProvider>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AddAccountDialog(),
    );
    if (result == null) return;
    try {
      await auth.createUser(
        username: result['username']!,
        displayName: result['name']!,
        role: result['role']!,
        pin: result['pin']!,
      );
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _editRole(Map<String, Object?> user) async {
    final auth = context.read<AuthProvider>();
    final updatedRole = await showDialog<String>(
      context: context,
      builder: (_) => _EditRoleDialog(
        displayName: user['display_name'].toString(),
        initialRole: roleLabel(user['role']),
      ),
    );
    if (updatedRole == null) return;
    try {
      await auth.setUserRole((user['id'] as num).toInt(), updatedRole);
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('จัดการบัญชีผู้ใช้'),
      actions: [
        IconButton(
          onPressed: _addUser,
          icon: const Icon(Icons.person_add_alt_1),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _users,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: snapshot.data!
              .map(
                (user) => SwitchListTile(
                  title: Text(user['display_name'].toString()),
                  subtitle: Text(
                    '${user['username']} • ${roleLabel(user['role'])}',
                  ),
                  value: (user['active'] as num) == 1,
                  secondary: IconButton(
                    tooltip: 'เปลี่ยนบทบาท',
                    onPressed: () => _editRole(user),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  onChanged: (active) async {
                    try {
                      await context.read<AuthProvider>().setUserActive(
                        (user['id'] as num).toInt(),
                        active,
                      );
                      if (!mounted) return;
                      setState(_load);
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.toString().replaceFirst('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'กรุณากรอกข้อมูล' : null;

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(subtitle),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EditRoleDialog extends StatefulWidget {
  final String displayName;
  final String initialRole;
  const _EditRoleDialog({required this.displayName, required this.initialRole});
  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  late final TextEditingController _role;
  @override
  void initState() {
    super.initState();
    _role = TextEditingController(text: widget.initialRole);
  }

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('เปลี่ยนบทบาทของ ${widget.displayName}'),
    content: TextField(
      controller: _role,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'บทบาท',
        helperText: 'ระบุบทบาทที่ต้องการ บัญชี admin ต้องคงบทบาทผู้จัดการ',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _role.text.trim()),
        child: const Text('บันทึกบทบาท'),
      ),
    ],
  );
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();
  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  final _role = TextEditingController(text: 'ผู้ใช้งานทั่วไป');
  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _pin.dispose();
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('เพิ่มบัญชีผู้ใช้งาน'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
          ),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
          ),
          TextField(
            controller: _role,
            decoration: const InputDecoration(
              labelText: 'บทบาท',
              helperText:
                  'ระบุบทบาท เช่น ผู้จัดการ ฝ่ายผลิต ฝ่ายจัดซื้อ หรือบทบาทอื่น',
            ),
          ),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัวอักษร)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          'name': _name.text,
          'username': _username.text,
          'pin': _pin.text,
          'role': _role.text,
        }),
        child: const Text('บันทึก'),
      ),
    ],
  );
}
