import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';

enum StockAction { receive, dispatch, adjust, produce }

class StockActionForm extends StatefulWidget {
  final String title;
  final StockAction action;

  const StockActionForm({super.key, required this.title, required this.action});

  @override
  State<StockActionForm> createState() => _StockActionFormState();
}

class _StockActionFormState extends State<StockActionForm> {
  String? code;

  final quantityController = TextEditingController();
  final noteController = TextEditingController();

  bool saving = false;

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    final choices = widget.action == StockAction.produce
        ? provider.finished
        : widget.action == StockAction.dispatch
        ? [...provider.raw, ...provider.finished]
        : provider.raw;

    if (code == null || !choices.any((item) => item.code == code)) {
      code = choices.isEmpty ? null : choices.first.code;
    }

    Item? selectedItem;

    for (final item in choices) {
      if (item.code == code) {
        selectedItem = item;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: code,
            decoration: const InputDecoration(
              labelText: 'เลือกสินค้า',
              border: OutlineInputBorder(),
            ),
            items: choices.map((item) {
              return DropdownMenuItem(
                value: item.code,
                child: Text(
                  '${item.name} '
                  '(${item.currentQuantity.toStringAsFixed(1)} ${item.unit})',
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => code = value);
            },
          ),
          if (selectedItem != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'คงเหลือปัจจุบัน: '
                '${selectedItem.currentQuantity} ${selectedItem.unit}',
              ),
            ),
          TextField(
            controller: quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.action == StockAction.adjust
                  ? 'ยอดคงเหลือใหม่'
                  : 'จำนวน',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'หมายเหตุ (ไม่บังคับ)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving || code == null ? null : () => _submit(context),
            child: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final quantity = double.tryParse(quantityController.text.trim());

    if (quantity == null ||
        quantity < 0 ||
        (widget.action != StockAction.adjust && quantity == 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนให้ถูกต้อง')));
      return;
    }

    setState(() => saving = true);

    try {
      final provider = context.read<InventoryProvider>();

      switch (widget.action) {
        case StockAction.receive:
          await provider.receive(code!, quantity, note: noteController.text);
          break;

        case StockAction.dispatch:
          await provider.dispatch(code!, quantity, note: noteController.text);
          break;

        case StockAction.adjust:
          await provider.adjust(code!, quantity, note: noteController.text);
          break;

        case StockAction.produce:
          await provider.produce(code!, quantity, note: noteController.text);
          break;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลแล้ว')));

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }
}
