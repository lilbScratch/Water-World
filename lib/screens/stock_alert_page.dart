import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';
import 'purchase_order_page.dart';
import 'purchase_order_history_page.dart';

class StockAlertPage extends StatelessWidget {
  const StockAlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    final criticalCount = provider.stockRisks
        .where((r) => r.level == StockRiskLevel.critical)
        .length;

    final warningCount = provider.stockRisks
        .where((r) => r.level == StockRiskLevel.warning)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('แจ้งเตือนสต็อก'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: provider.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard('สต็อกวิกฤต', criticalCount, Colors.red),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    'ใกล้ถึงจุดสั่งซื้อ',
                    warningCount,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ปุ่มสร้างรายการสั่งซื้อ
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PurchaseOrderPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('สร้างรายการสั่งซื้อ'),
              ),
            ),

            const SizedBox(height: 8),

            // ปุ่มดูรายการสั่งซื้อที่บันทึกไว้
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PurchaseOrderHistoryPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('ดูรายการสั่งซื้อที่บันทึกไว้'),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'รายละเอียดวัตถุดิบ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            if (provider.stockRisks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('ไม่พบข้อมูลวัตถุดิบ')),
              ),

            ...provider.stockRisks.map((risk) => _riskCard(context, risk)),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, int count, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            Text(
              '$count รายการ',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskCard(BuildContext context, StockRisk risk) {
    final color = switch (risk.level) {
      StockRiskLevel.normal => Colors.green,
      StockRiskLevel.warning => Colors.orange,
      StockRiskLevel.critical => Colors.red,
    };

    final label = switch (risk.level) {
      StockRiskLevel.normal => 'ปกติ',
      StockRiskLevel.warning => 'ใกล้ถึงจุดสั่งซื้อ',
      StockRiskLevel.critical => 'วิกฤต',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    risk.item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(label),
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
                IconButton(
                  tooltip: 'ตั้งค่านโยบายสต็อก',
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    _showPolicyDialog(context, risk);
                  },
                ),
              ],
            ),

            Text(
              'คงเหลือ: '
              '${risk.item.currentQuantity.toStringAsFixed(2)} '
              '${risk.item.unit}',
            ),
            Text(
              'ใช้เฉลี่ยต่อวัน: '
              '${risk.averageDailyUsage.toStringAsFixed(2)} '
              '${risk.item.unit}',
            ),
            Text(
              'Safety Stock: '
              '${risk.safetyStock.toStringAsFixed(2)} '
              '${risk.item.unit}',
            ),
            Text(
              'จุดสั่งซื้อ: '
              '${risk.reorderPoint.toStringAsFixed(2)} '
              '${risk.item.unit}',
            ),
            Text(
              'แนะนำให้สั่ง: '
              '${risk.suggestedOrderQuantity.toStringAsFixed(2)} '
              '${risk.item.unit}',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPolicyDialog(BuildContext context, StockRisk risk) async {
    final provider = context.read<InventoryProvider>();

    await showDialog<void>(
      context: context,
      builder: (_) => _StockPolicyDialog(risk: risk, provider: provider),
    );
  }
}

class _StockPolicyDialog extends StatefulWidget {
  const _StockPolicyDialog({required this.risk, required this.provider});

  final StockRisk risk;
  final InventoryProvider provider;

  @override
  State<_StockPolicyDialog> createState() => _StockPolicyDialogState();
}

class _StockPolicyDialogState extends State<_StockPolicyDialog> {
  late final TextEditingController leadController;
  late final TextEditingController targetController;
  late final TextEditingController safetyController;
  late final TextEditingController reorderController;

  late double z;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final item = widget.risk.item;

    leadController = TextEditingController(text: '${item.leadTimeDays}');

    targetController = TextEditingController(text: '${item.targetDays}');

    safetyController = TextEditingController(
      text: item.safetyStock > 0 ? '${item.safetyStock}' : '',
    );

    reorderController = TextEditingController(
      text: item.minQuantity > 0 ? '${item.minQuantity}' : '',
    );

    z = item.serviceLevelZ;
  }

  @override
  void dispose() {
    leadController.dispose();
    targetController.dispose();
    safetyController.dispose();
    reorderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;

    final lead = int.tryParse(leadController.text.trim());

    final target = int.tryParse(targetController.text.trim());

    final safetyText = safetyController.text.trim();
    final reorderText = reorderController.text.trim();

    final safety = safetyText.isEmpty ? 0.0 : double.tryParse(safetyText);

    final reorder = reorderText.isEmpty ? 0.0 : double.tryParse(reorderText);

    if (lead == null ||
        target == null ||
        lead < 1 ||
        target < 1 ||
        safety == null ||
        reorder == null ||
        safety < 0 ||
        reorder < 0) {
      showAppMessage(context, 'กรุณาตรวจสอบค่าที่กรอก');
      return;
    }

    setState(() => saving = true);

    try {
      await widget.provider.saveStockPolicy(
        code: widget.risk.item.code,
        leadTimeDays: lead,
        targetDays: target,
        serviceLevelZ: z,
        safetyStock: safety,
        minQuantity: reorder,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      showAppMessage(context, 'บันทึกการตั้งค่าแล้ว');
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ตั้งค่าสต็อก'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: leadController,
              keyboardType: TextInputType.number,
              decoration: inputDecoration('ระยะเวลารอสินค้า (วัน)'),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: inputDecoration('จำนวนวันที่ต้องการสำรอง'),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: safetyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: inputDecoration(
                'Safety Stock เอง (ว่าง = อัตโนมัติ)',
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: reorderController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: inputDecoration('จุดสั่งซื้อเอง (ว่าง = อัตโนมัติ)'),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<double>(
              value: z,
              decoration: inputDecoration('ระดับการบริการ'),
              items: const [
                DropdownMenuItem(value: 1.28, child: Text('90%')),
                DropdownMenuItem(value: 1.65, child: Text('95%')),
                DropdownMenuItem(value: 2.33, child: Text('99%')),
              ],
              onChanged: saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => z = value);
                      }
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
        ),
      ],
    );
  }
}
