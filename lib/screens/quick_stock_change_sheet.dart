// Captures several stock adjustments before applying them together.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';

class QuickStockChangeSheet extends StatefulWidget {
  const QuickStockChangeSheet({super.key, required this.item});

  final Item item;

  @override
  State<QuickStockChangeSheet> createState() => _QuickStockChangeSheetState();
}

class _QuickStockChangeSheetState extends State<QuickStockChangeSheet> {
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  bool _adding = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _quantity.addListener(_updatePreview);
  }

  void _updatePreview() => setState(() {});

  @override
  void dispose() {
    _quantity.removeListener(_updatePreview);
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final amount = double.tryParse(_quantity.text.trim());
    final next = amount == null
        ? null
        : item.currentQuantity + (_adding ? amount : -amount);
    final valid =
        amount != null &&
        amount.isFinite &&
        amount > 0 &&
        next != null &&
        next >= item.reservedQuantity;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'คงเหลือ ${qtyFmt.format(item.currentQuantity)} ${item.unit}',
              ),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.add),
                    label: Text('รับเข้า'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.remove),
                    label: Text('เบิกออก'),
                  ),
                ],
                selected: {_adding},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() => _adding = selection.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantity,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'จำนวนที่${_adding ? 'รับเข้า' : 'เบิกออก'} (${item.unit})',
                  border: const OutlineInputBorder(),
                  errorText: amount != null && amount > 0 && !valid
                      ? 'จำนวนเกินยอดที่เบิกได้'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                valid
                    ? 'หลังบันทึก: ${qtyFmt.format(next)} ${item.unit}'
                    : 'กรอกจำนวนเพื่อดูยอดหลังบันทึก',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: !_saving && valid ? _submit : null,
                icon: Icon(
                  _adding
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                ),
                label: Text(
                  _saving
                      ? 'กำลังบันทึก...'
                      : 'ยืนยัน${_adding ? 'รับเข้า' : 'เบิกออก'}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_quantity.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) return;
    setState(() => _saving = true);
    try {
      final inventory = context.read<InventoryProvider>();
      if (_adding) {
        await inventory.receive(
          widget.item.code,
          amount,
          note: _note.text.trim(),
        );
      } else {
        await inventory.dispatch(
          widget.item.code,
          amount,
          note: _note.text.trim(),
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(appSnackBar(const Text('บันทึกยอดสต็อกแล้ว')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
