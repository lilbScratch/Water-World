// Shows stock balances and provides quick inventory actions.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';
import 'adjust_page.dart';
import 'create_item_page.dart';
import 'dispatch_page.dart';
import 'production_page.dart';
import 'receive_page.dart';
import 'quick_stock_change_sheet.dart';

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
          actions: [
            IconButton(
              tooltip: 'เพิ่มรายการสินค้า',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateItemPage()),
              ),
            ),
          ],
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
    Widget action(
      String label,
      IconData icon,
      Widget page, {
      bool primary = false,
    }) {
      void open() =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      return primary
          ? FilledButton.icon(
              onPressed: open,
              icon: Icon(icon),
              label: Text(label),
            )
          : FilledButton.tonalIcon(
              onPressed: open,
              icon: Icon(icon),
              label: Text(label),
            );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: action(
                  'รับเข้าสต็อก',
                  Icons.add,
                  const ReceivePage(),
                  primary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: action(
                  'บันทึกผลิต',
                  Icons.factory,
                  const ProductionPage(),
                  primary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: action('เบิกออก', Icons.remove, const DispatchPage()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: action('นับยอดใหม่', Icons.tune, const AdjustPage()),
              ),
            ],
          ),
        ],
      ),
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
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => QuickStockChangeSheet(item: item),
            ),
            title: Text(item.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.code} • หน่วย: ${item.unit}'),
                const Text('แตะเพื่อรับเข้าหรือเบิกออก'),
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
