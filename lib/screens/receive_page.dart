// Records multiple raw material receipts in one save.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final List<_ReceiptLine> _lines = [_ReceiptLine()];
  bool _saving = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<InventoryProvider>().raw;
    if (_lines.length == 1 && _lines.first.code == null && items.isNotEmpty) {
      _lines.first.code = items.first.code;
    }

    final selectedCodes = _lines
        .map((line) => line.code)
        .whereType<String>()
        .toSet();
    final unusedItems = items
        .where((item) => !selectedCodes.contains(item.code))
        .toList();
    final canSave =
        !_saving &&
        _lines.isNotEmpty &&
        _lines.every((line) {
          final quantity = double.tryParse(line.quantity.text.trim());
          return line.code != null &&
              quantity != null &&
              quantity.isFinite &&
              quantity > 0;
        });

    return Scaffold(
      appBar: AppBar(title: const Text('รับวัตถุดิบเข้า')),
      body: items.isEmpty
          ? const Center(child: Text('ยังไม่มีรายการวัตถุดิบ'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      Text(
                        'เพิ่มรายการที่รับเข้าวันนี้ แล้วบันทึกพร้อมกัน',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      for (var index = 0; index < _lines.length; index++)
                        _receiptCard(
                          context,
                          items: items,
                          line: _lines[index],
                          index: index,
                          selectedCodes: selectedCodes,
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _saving || unusedItems.isEmpty
                              ? null
                              : () => setState(() {
                                  _lines.add(
                                    _ReceiptLine(code: unusedItems.first.code),
                                  );
                                }),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มสินค้า'),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canSave ? _save : null,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'กำลังบันทึก...'
                              : 'บันทึกรับเข้าทั้งหมด (${_lines.length} รายการ)',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _receiptCard(
    BuildContext context, {
    required List<Item> items,
    required _ReceiptLine line,
    required int index,
    required Set<String> selectedCodes,
  }) {
    final choices = items
        .where(
          (item) =>
              item.code == line.code || !selectedCodes.contains(item.code),
        )
        .toList();
    Item? item;
    for (final choice in items) {
      if (choice.code == line.code) item = choice;
    }
    final quantity = double.tryParse(line.quantity.text.trim());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'รายการ ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_lines.length > 1)
                  IconButton(
                    tooltip: 'ลบรายการ',
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _lines.removeAt(index).dispose();
                          }),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: line.code,
              decoration: const InputDecoration(
                labelText: 'เลือกสินค้า',
                border: OutlineInputBorder(),
              ),
              items: choices
                  .map(
                    (choice) => DropdownMenuItem(
                      value: choice.code,
                      child: Text(
                        '${choice.name} (${choice.currentQuantity} ${choice.unit})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (code) => setState(() => line.code = code),
            ),
            if (item != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'คงเหลือ ${qtyFmt.format(item.currentQuantity)} ${item.unit}',
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: line.quantity,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: item == null
                    ? 'จำนวนรับเข้า'
                    : 'จำนวนรับเข้า (${item.unit})',
                border: const OutlineInputBorder(),
              ),
            ),
            if (item != null && quantity != null && quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'หลังรับเข้า: ${qtyFmt.format(item.currentQuantity + quantity)} ${item.unit}',
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: line.note,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ไม่บังคับ)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final receipts = <({String code, double quantity, String note})>[];
    for (final line in _lines) {
      final quantity = double.tryParse(line.quantity.text.trim());
      if (line.code == null ||
          quantity == null ||
          !quantity.isFinite ||
          quantity <= 0) {
        showAppMessage(context, 'เลือกสินค้าและกรอกจำนวนให้ถูกต้องทุกรายการ');
        return;
      }
      receipts.add((
        code: line.code!,
        quantity: quantity,
        note: line.note.text.trim(),
      ));
    }

    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().receiveMany(receipts);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        appSnackBar(const Text('บันทึกรับวัตถุดิบทั้งหมดแล้ว')),
      );
    } catch (error) {
      if (mounted) showAppMessage(context, '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ReceiptLine {
  _ReceiptLine({this.code});

  String? code;
  final quantity = TextEditingController();
  final note = TextEditingController();

  void dispose() {
    quantity.dispose();
    note.dispose();
  }
}
