import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';
import 'adjust_page.dart';
import 'dispatch_page.dart';
import 'production_page.dart';
import 'receive_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InventoryProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('คลังสินค้า'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'วัตถุดิบ'),
              Tab(text: 'สินค้าสำเร็จรูป'),
            ],
          ),
        ),
        body: p.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _quickActions(context),
                  if (p.stockRisks.any((r) => r.level != StockRiskLevel.normal))
                    _alertSummary(context, p.stockRisks),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _itemList(p.raw, p.stockRisks),
                        _itemList(p.finished, const []),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _alertSummary(BuildContext context, List<StockRisk> risks) {
    final critical = risks
        .where((r) => r.level == StockRiskLevel.critical)
        .length;
    final warning = risks
        .where((r) => r.level == StockRiskLevel.warning)
        .length;

    return Card(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: critical > 0
                  ? Theme.of(context).colorScheme.error
                  : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'แจ้งเตือนสต๊อกวัตถุดิบ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'วิกฤต $critical รายการ • ใกล้ถึงจุดสั่งซื้อ $warning รายการ',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    Widget b(String label, IconData icon, Widget page) => Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
        child: FilledButton.tonal(
          onPressed: () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            minimumSize: Size.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        b('รับเข้า', Icons.input, const ReceivePage()),
        b('ผลิต', Icons.factory, const ProductionPage()),
        b('ขาย/ส่ง', Icons.local_shipping, const DispatchPage()),
        b('ปรับยอด', Icons.tune, const AdjustPage()),
      ],
    );
  }

  Widget _itemList(List<Item> items, List<StockRisk> risks) {
    if (items.isEmpty) {
      return const Center(child: Text('ไม่มีรายการ'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];

        StockRisk? risk;
        for (final r in risks) {
          if (r.item.code == item.code) {
            risk = r;
            break;
          }
        }

        final scheme = Theme.of(context).colorScheme;
        final isCritical = risk?.level == StockRiskLevel.critical;
        final isWarning = risk?.level == StockRiskLevel.warning;

        final Color statusColor = isCritical
            ? scheme.error
            : isWarning
            ? Colors.orange.shade800
            : scheme.primary;

        final String statusText = risk == null
            ? 'ยังไม่มีข้อมูลเกณฑ์เตือน'
            : isCritical
            ? 'วิกฤต: ต่ำกว่า Safety Stock'
            : isWarning
            ? 'ใกล้ถึงจุดสั่งซื้อ'
            : 'ปกติ';

        return Card(
          child: ListTile(
            title: Text(item.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.code} • หน่วย: ${item.unit}'),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (risk != null) ...[
                  Text(
                    'Safety Stock: ${qtyFmt.format(risk.safetyStock)} ${item.unit}',
                  ),
                  Text(
                    'จุดสั่งซื้อ: ${qtyFmt.format(risk.reorderPoint)} ${item.unit}',
                  ),
                  if (risk.suggestedOrderQuantity > 0)
                    Text(
                      'แนะนำสั่งเพิ่ม: '
                      '${qtyFmt.format(risk.suggestedOrderQuantity)} ${item.unit}',
                      style: TextStyle(color: scheme.error),
                    ),
                ] else if (item.safetyStock <= 0 && item.minQuantity <= 0) ...[
                  const Text('กรุณากำหนด Safety Stock หรือจุดสั่งซื้อ'),
                ],
              ],
            ),
            isThreeLine: true,
            trailing: Text(
              '${qtyFmt.format(item.currentQuantity)} ${item.unit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      },
    );
  }
}
