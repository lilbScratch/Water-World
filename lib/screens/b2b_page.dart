import '../thai_labels.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/stock_repository.dart';
import '../models.dart';
import '../order_models.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';

part 'b2b_order_dialog.dart';

class B2BPage extends StatefulWidget {
  const B2BPage({super.key});
  @override
  State<B2BPage> createState() => _B2BPageState();
}

class _B2BPageState extends State<B2BPage> {
  late Future<List<Map<String, Object?>>> _orders;
  StockRepository get _repo => context.read<InventoryProvider>().repo;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _orders = _repo.b2bOrders();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(_reload);
    await _orders;
  }

  Future<void> _run(Future<void> Function() action) async {
    final inventory = context.read<InventoryProvider>();
    try {
      await action();
      await inventory.refresh();
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _addCustomer() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _AddB2BCustomerDialog(),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      await _repo.addB2BCustomer(
        name: result[0],
        contactPerson: result[1],
        phone: result[2],
        address: result[3],
      );
    });
  }

  Future<void> _newOrder() async {
    final inventory = context.read<InventoryProvider>();
    await _run(() async {
      final customers = await _repo.b2bCustomers();
      if (!mounted) return;
      if (customers.isEmpty || inventory.finished.isEmpty) {
        throw AppException('กรุณาเพิ่มลูกค้าและสินค้าสำเร็จรูปก่อน');
      }
      final values = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) =>
            _B2BOrderDialog(customers, inventory.finished, inventory.repo),
      );
      if (values == null) return;
      await inventory.repo.createB2BOrder(
        customerId: values['customer_id'] as int,
        items: (values['items'] as List).cast<Map<String, Object?>>(),
        deliveryDate: values['delivery_date'] as DateTime,
        notes: values['notes'] as String,
      );
    });
  }

  Future<void> _action(String action, int id) async {
    if (action == 'cancel') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('ยกเลิกคำสั่งซื้อ #$id หรือไม่?'),
          content: const Text(
            'ระบบจะคืนยอดสำรองสินค้าและวัตถุดิบให้พร้อมใช้งาน',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('เก็บคำสั่งซื้อไว้'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('ยกเลิกคำสั่งซื้อ'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _run(
      () => switch (action) {
        'confirm' => _repo.confirmB2BOrder(id),
        'produce' => _repo.produceB2BOrder(id),
        'fulfill' => _repo.fulfillB2BOrder(id),
        _ => _repo.cancelB2BOrder(id),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          auth.canManageOrders ? 'ลูกค้าและคำสั่งซื้อขายส่ง' : 'คำสั่งผลิต',
        ),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Text('ไม่สามารถโหลดคำสั่งซื้อได้: ${snapshot.error}'),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data!
                .where(
                  (o) =>
                      auth.canManageOrders ||
                      o['status'] == 'awaiting_production',
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (auth.canManageOrders)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _newOrder,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('สร้างคำสั่งซื้อ'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addCustomer,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('เพิ่มลูกค้า'),
                      ),
                    ],
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'ฉบับร่าง → สำรองสินค้า / รอผลิต → พร้อมจัดส่ง → จัดส่งแล้ว',
                  ),
                ),
                if (orders.isEmpty) const Text('ยังไม่มีคำสั่งซื้อ'),
                ...orders.map((order) {
                  final id = (order['id'] as num).toInt();
                  final status = order['status'] as String;
                  final actions = <PopupMenuEntry<String>>[
                    if (auth.canManageOrders && status == 'draft')
                      const PopupMenuItem(
                        value: 'confirm',
                        child: Text('ตรวจสอบและสำรองสินค้า'),
                      ),
                    if (auth.canManageInventory &&
                        status == 'awaiting_production')
                      const PopupMenuItem(
                        value: 'produce',
                        child: Text('บันทึกการผลิตตามคำสั่งซื้อ'),
                      ),
                    if (auth.canManageOrders && status == 'confirmed')
                      const PopupMenuItem(
                        value: 'fulfill',
                        child: Text('ยืนยันการจัดส่ง'),
                      ),
                    if (auth.canManageOrders &&
                        [
                          'draft',
                          'confirmed',
                          'awaiting_production',
                        ].contains(status))
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('ยกเลิกคำสั่งซื้อ'),
                      ),
                  ];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('#$id')),
                      title: Text(
                        '${order['customer_name']} • ${((order['total'] as num?) ?? 0).toStringAsFixed(2)} บาท',
                      ),
                      subtitle: Text(
                        '${orderStatusLabel(status)} • ${order['line_count']} รายการ\nกำหนดส่ง: ${order['delivery_date'] ?? 'คำสั่งซื้อเดิม: ไม่ระบุวันที่'} • ${order['notes']}',
                      ),
                      isThreeLine: true,
                      trailing: actions.isEmpty
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (a) => _action(a, id),
                              itemBuilder: (_) => actions,
                            ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddB2BCustomerDialog extends StatefulWidget {
  const _AddB2BCustomerDialog();

  @override
  State<_AddB2BCustomerDialog> createState() => _AddB2BCustomerDialogState();
}

class _AddB2BCustomerDialogState extends State<_AddB2BCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('เพิ่มลูกค้าขายส่ง'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'ชื่อกิจการ'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'กรุณากรอกข้อมูล'
                  : null,
            ),
            TextField(
              controller: _contact,
              decoration: const InputDecoration(labelText: 'ชื่อผู้ติดต่อ'),
            ),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
            ),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'ที่อยู่'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState?.validate() ?? false) {
            Navigator.pop(context, [
              _name.text,
              _contact.text,
              _phone.text,
              _address.text,
            ]);
          }
        },
        child: const Text('บันทึก'),
      ),
    ],
  );
}
