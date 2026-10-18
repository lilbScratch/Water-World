import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/stock_repository.dart';
import '../models.dart';
import '../order_models.dart';
import '../providers/inventory_provider.dart';

class RecipeSetupPage extends StatelessWidget {
  const RecipeSetupPage({super.key});
  Future<void> _edit(BuildContext context, Item product) async {
    final inventory = context.read<InventoryProvider>();
    try {
      final recipe = await inventory.repo.recipeFor(product.code);
      if (!context.mounted) return;
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => _RecipeDialog(product, inventory.raw, recipe),
      );
      if (result == null) return;
      await inventory.repo.saveRecipe(
        productCode: product.code,
        materials: (result['materials'] as List).cast<Map<String, Object?>>(),
        productionLeadDays: result['days'] as int,
      );
      await inventory.refresh();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('สูตรการผลิต')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'ระบุปริมาณวัตถุดิบที่ใช้จริงสำหรับผลิตสินค้าสำเร็จรูป 1 หน่วย '
              'ระบบไม่กำหนดสูตรโรงงานให้ล่วงหน้า ระยะเวลาผลิตเป็นค่าประเมินเพื่อวางแผน โดยนับเป็นวันปฏิทิน',
            ),
          ),
          ...inventory.finished.map(
            (p) => ListTile(
              title: Text(p.name),
              subtitle: Text(
                'วัตถุดิบ ${inventory.recipes.where((r) => r.finishedCode == p.code).length} รายการต่อ 1 ${p.unit} • ระยะเวลาผลิต ${p.productionLeadDays} วัน',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, p),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeDialog extends StatefulWidget {
  final Item product;
  final List<Item> raw;
  final List<RecipeLine> recipe;
  const _RecipeDialog(this.product, this.raw, this.recipe);
  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _days;
  late final Map<String, TextEditingController> _quantities;
  String? _error;
  @override
  void initState() {
    super.initState();
    _days = TextEditingController(text: '${widget.product.productionLeadDays}');
    _quantities = {
      for (final raw in widget.raw)
        raw.code: TextEditingController(
          text: widget.recipe
              .where((r) => r.rawCode == raw.code)
              .fold<double>(0, (s, r) => s + r.quantity)
              .toString(),
        ),
    };
  }

  @override
  void dispose() {
    _days.dispose();
    for (final c in _quantities.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('สูตรการผลิต: ${widget.product.name}'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ปริมาณวัตถุดิบต่อสินค้า 1 ${widget.product.unit} ระบุ 0 สำหรับวัตถุดิบที่ไม่ใช้',
              ),
              TextFormField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ระยะเวลาผลิต (วัน)',
                ),
                validator: (s) {
                  final d = int.tryParse(s ?? '');
                  return d == null || d < 0 || d > 365
                      ? 'กรุณาระบุระยะเวลา 0–365 วัน'
                      : null;
                },
              ),
              ...widget.raw.map(
                (r) => TextFormField(
                  controller: _quantities[r.code],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${r.name} (${r.unit})',
                  ),
                  validator: (s) {
                    final n = double.tryParse(s ?? '');
                    return n == null || !n.isFinite || n < 0
                        ? 'กรุณาระบุจำนวนตั้งแต่ 0 ขึ้นไป'
                        : null;
                  },
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
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
          if (!_key.currentState!.validate()) return;
          final lines = _quantities.entries
              .where((e) => double.parse(e.value.text) > 0)
              .map(
                (e) => <String, Object?>{
                  'material_code': e.key,
                  'quantity': double.parse(e.value.text),
                },
              )
              .toList();
          if (lines.isEmpty) {
            setState(() => _error = 'กรุณาเพิ่มวัตถุดิบอย่างน้อย 1 รายการ');
            return;
          }
          Navigator.pop(context, <String, Object?>{
            'materials': lines,
            'days': int.parse(_days.text),
          });
        },
        child: const Text('บันทึกสูตรการผลิต'),
      ),
    ],
  );
}

class PurchaseReceiptsPage extends StatefulWidget {
  const PurchaseReceiptsPage({super.key});
  @override
  State<PurchaseReceiptsPage> createState() => _PurchaseReceiptsPageState();
}

class _PurchaseReceiptsPageState extends State<PurchaseReceiptsPage> {
  late Future<List<Map<String, Object?>>> _receipts;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _receipts = context.read<InventoryProvider>().repo.purchaseReceipts();
  }

  Future<void> _add() async {
    final inventory = context.read<InventoryProvider>();
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _ReceiptDialog(inventory.raw),
    );
    if (values == null) return;
    try {
      await inventory.repo.recordPurchaseReceipt(
        itemCode: values['code'] as String,
        quantity: values['quantity'] as double,
        unitPrice: values['price'] as double,
        supplier: values['supplier'] as String,
        reference: values['reference'] as String,
        purchasedAt: values['date'] as DateTime,
      );
      await inventory.refresh();
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ใบรับสินค้าจากการซื้อ')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('บันทึกใบรับสินค้า'),
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _receipts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('ไม่สามารถโหลดใบรับสินค้าได้: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: [
            const Text(
              'ระบุราคาตามใบแจ้งหนี้หรือใบเสร็จของผู้จำหน่าย เมื่อบันทึก ระบบจะเพิ่มสต็อกและเก็บราคาซื้อครั้งนั้นเป็นประวัติ ห้ามบันทึกรับเข้าสินค้าชุดเดียวกันซ้ำในหน้ารับเข้า',
            ),
            if (snapshot.data!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ยังไม่มีประวัติการซื้อ ระบบจะแสดงราคาเมื่อมีการบันทึกใบรับสินค้า',
                ),
              ),
            ...snapshot.data!.map(
              (r) => Card(
                child: ListTile(
                  title: Text(
                    '${r['item_name']} • ฿${r['unit_price']}/${r['unit']}',
                  ),
                  subtitle: Text(
                    '${r['purchased_at']} • ${r['quantity']} ${r['unit']}\n${r['supplier']} • ${r['reference']}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ReceiptDialog extends StatefulWidget {
  final List<Item> raw;
  const _ReceiptDialog(this.raw);
  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  final _key = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  String? _code;
  DateTime _date = DateTime.now();
  @override
  void dispose() {
    for (final c in [_quantity, _price, _supplier, _reference]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('บันทึกรับสินค้าจากการซื้อ'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _code,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'วัตถุดิบ'),
                items: widget.raw
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.code,
                        child: Text('${r.name} / ${r.unit}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _code = v),
                validator: (s) => s == null ? 'กรุณาเลือกรายการ' : null,
              ),
              TextFormField(
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'จำนวนที่รับเข้าจริง',
                ),
                validator: (s) {
                  final n = double.tryParse(s ?? '');
                  return n == null || !n.isFinite || n <= 0
                      ? 'กรุณาระบุจำนวนมากกว่า 0'
                      : null;
                },
              ),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ราคาซื้อจริงต่อหน่วย (บาท)',
                ),
                validator: (s) {
                  final n = double.tryParse(s ?? '');
                  return n == null || !n.isFinite || n < 0
                      ? 'กรุณาระบุราคาตั้งแต่ 0 ขึ้นไป'
                      : null;
                },
              ),
              TextFormField(
                controller: _supplier,
                decoration: const InputDecoration(labelText: 'ผู้จำหน่าย'),
                validator: (s) =>
                    s == null || s.trim().isEmpty ? 'กรุณากรอกข้อมูล' : null,
              ),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'เลขที่ใบแจ้งหนี้ / ใบเสร็จ',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (mounted && date != null) setState(() => _date = date);
                },
                child: Text('วันที่ซื้อ: ${dateOnly(_date)}'),
              ),
              const Text(
                'เมื่อบันทึก ระบบจะเพิ่มจำนวนนี้เข้าสต็อก กรุณาบันทึกเฉพาะสินค้าที่รับจริง',
              ),
            ],
          ),
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
          if (!_key.currentState!.validate()) return;
          Navigator.pop(context, <String, Object?>{
            'code': _code!,
            'quantity': double.parse(_quantity.text),
            'price': double.parse(_price.text),
            'supplier': _supplier.text,
            'reference': _reference.text,
            'date': _date,
          });
        },
        child: const Text('บันทึกการรับสินค้า'),
      ),
    ],
  );
}
