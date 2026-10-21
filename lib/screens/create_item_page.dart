// Form for adding an inventory or finished-product item.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';

class CreateItemPage extends StatefulWidget {
  const CreateItemPage({super.key});

  @override
  State<CreateItemPage> createState() => _CreateItemPageState();
}

class _CreateItemPageState extends State<CreateItemPage> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _unit = TextEditingController();
  final _initialQuantity = TextEditingController();
  final _unitCost = TextEditingController();
  String _type = 'raw';
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _unit.dispose();
    _initialQuantity.dispose();
    _unitCost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('เพิ่มรายการสินค้า')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'สร้างรายการก่อน แล้วแตะรายการในคลังเพื่อรับเข้าหรือเบิกออก',
        ),
        const SizedBox(height: 20),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'raw', label: Text('วัตถุดิบ')),
            ButtonSegment(value: 'finished', label: Text('สินค้าสำเร็จรูป')),
          ],
          selected: {_type},
          onSelectionChanged: _saving
              ? null
              : (selection) => setState(() => _type = selection.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'รหัสสินค้า เช่น FILM_600',
            helperText: 'ตัวอักษรอังกฤษ ตัวเลข และ _',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'ชื่อสินค้า เช่น ฟิล์ม 600',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _unit,
          decoration: const InputDecoration(
            labelText: 'หน่วย เช่น ม้วน หรือ แพ็ก',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _initialQuantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'ยอดตั้งต้น (ไม่บังคับ)',
            helperText: 'ใส่ 0 หรือเว้นว่าง หากยังไม่มีของในคลัง',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _unitCost,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'ต้นทุนต่อหน่วย (ไม่บังคับ)',
            prefixText: '฿ ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.add_box_outlined),
          label: Text(_saving ? 'กำลังบันทึก...' : 'สร้างรายการ'),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    final quantityText = _initialQuantity.text.trim();
    final costText = _unitCost.text.trim();
    final initialQuantity = quantityText.isEmpty
        ? 0.0
        : double.tryParse(quantityText);
    final unitCost = costText.isEmpty ? 0.0 : double.tryParse(costText);
    if (initialQuantity == null ||
        !initialQuantity.isFinite ||
        initialQuantity < 0 ||
        unitCost == null ||
        !unitCost.isFinite ||
        unitCost < 0) {
      showAppMessage(context, 'ตรวจสอบยอดตั้งต้นและต้นทุนอีกครั้ง');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().createItem(
        code: _code.text,
        name: _name.text,
        type: _type,
        unit: _unit.text,
        initialQuantity: initialQuantity,
        unitCost: unitCost,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(appSnackBar(const Text('สร้างรายการสินค้าแล้ว')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
