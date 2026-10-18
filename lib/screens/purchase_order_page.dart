import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';

class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  final Map<String, bool> selected = {};
  final Map<String, TextEditingController> quantities = {};

  bool saving = false;

  @override
  void dispose() {
    for (final controller in quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    final risks = provider.stockRisks
        .where((risk) => risk.level != StockRiskLevel.normal)
        .toList();

    for (final risk in risks) {
      selected.putIfAbsent(risk.item.code, () => true);

      quantities.putIfAbsent(
        risk.item.code,
        () => TextEditingController(
          text: risk.suggestedOrderQuantity.ceil().toString(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('สร้างรายการสั่งซื้อ')),
      body: risks.isEmpty
          ? const Center(child: Text('ยังไม่มีวัตถุดิบที่ต้องสั่งซื้อ'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('เลือกรายการและตรวจสอบจำนวนที่ต้องการสั่งซื้อ'),
                const SizedBox(height: 8),
                ...risks.map((risk) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: selected[risk.item.code] ?? false,
                            onChanged: (value) {
                              setState(() {
                                selected[risk.item.code] = value ?? false;
                              });
                            },
                            title: Text(risk.item.name),
                            subtitle: Text(
                              'คงเหลือ ${risk.item.currentQuantity.toStringAsFixed(2)} ${risk.item.unit}\n'
                              'แนะนำสั่ง ${risk.suggestedOrderQuantity.ceil()} ${risk.item.unit}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            isThreeLine: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              controller: quantities[risk.item.code],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: inputDecoration(
                                'จำนวนที่จะสั่ง (${risk.item.unit})',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: saving ? null : () => _saveOrder(context, risks),
                  icon: const Icon(Icons.save),
                  label: Text(
                    saving ? 'กำลังบันทึก...' : 'บันทึกร่างรายการสั่งซื้อ',
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveOrder(BuildContext context, List<StockRisk> risks) async {
    final orderItems = <Map<String, Object?>>[];

    for (final risk in risks) {
      if (selected[risk.item.code] != true) {
        continue;
      }

      final quantity =
          double.tryParse(quantities[risk.item.code]?.text.trim() ?? '') ?? 0;

      if (quantity <= 0) {
        showAppMessage(
          context,
          'กรุณากรอกจำนวนของ ${risk.item.name} ให้มากกว่า 0',
        );
        return;
      }

      orderItems.add({
        'code': risk.item.code,
        'name': risk.item.name,
        'unit': risk.item.unit,
        'quantity': quantity,
        'unit_cost': risk.item.unitCost,
      });
    }

    if (orderItems.isEmpty) {
      showAppMessage(context, 'กรุณาเลือกสินค้าอย่างน้อย 1 รายการ');
      return;
    }

    setState(() => saving = true);

    try {
      final id = await context.read<InventoryProvider>().createPurchaseOrder(
        orderItems,
      );

      if (!mounted) return;

      showAppMessage(context, 'บันทึกร่างรายการสั่งซื้อเลขที่ $id แล้ว');

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('ร่างใบสั่งซื้อ #$id'),
          content: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(orderItems),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppMessage(context, '$error');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }
}
