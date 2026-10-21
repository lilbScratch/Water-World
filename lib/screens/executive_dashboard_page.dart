// Shows grouped management metrics and historical charts.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/stock_repository.dart';
import '../models.dart';
import '../providers/inventory_provider.dart';
import 'planning_data_page.dart';
import 'auth_gate.dart';
import '../providers/auth_provider.dart';

class ExecutiveDashboardPage extends StatefulWidget {
  const ExecutiveDashboardPage({super.key});
  @override
  State<ExecutiveDashboardPage> createState() => _ExecutiveDashboardPageState();
}

class _ExecutiveDashboardPageState extends State<ExecutiveDashboardPage> {
  int _days = 7;
  int? _revision;
  late Future<List<Map<String, Object?>>> _data;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inventory = context.watch<InventoryProvider>();
    if (_revision != inventory.revision) {
      _revision = inventory.revision;
      _data = inventory.repo.dashboardStats(days: _days);
    }
  }

  void _load() {
    _data = context.read<InventoryProvider>().repo.dashboardStats(days: _days);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _data;
  }

  double _number(Object? n) => n is num ? n.toDouble() : 0;
  List<Map<String, Object?>> _rows(Object? value) =>
      (value as List).cast<Map<String, Object?>>();
  Widget _metric(String label, String value) => SizedBox(
    width: 165,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label),
          ],
        ),
      ),
    ),
  );
  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      children: children,
    ),
  );
  Widget _bars(List<MapEntry<String, double>> values, String unit) {
    final maxValue = values.fold<double>(1, (n, e) => math.max(n, e.value));
    return Column(
      children: values
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.key}: ${e.value.toStringAsFixed(2)} $unit'),
                  LinearProgressIndicator(
                    value: (e.value / maxValue).clamp(0, 1).toDouble(),
                    minHeight: 10,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ภาพรวมสำหรับผู้จัดการ'),
      actions: [
        DropdownButton<int>(
          value: _days,
          items: const [
            DropdownMenuItem(value: 1, child: Text('วันนี้')),
            DropdownMenuItem(value: 7, child: Text('7 วัน')),
            DropdownMenuItem(value: 30, child: Text('30 วัน')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _days = v;
                _load();
              });
            }
          },
        ),
        IconButton(
          tooltip: 'รีเฟรชภาพรวม',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ไม่สามารถโหลดข้อมูลภาพรวมได้: ${snapshot.error}'),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final first = snapshot.data!.first;
        final summary = first['summary'] as Map<String, Object?>;
        final prices = _rows(first['purchase_prices']);
        final distribution = _rows(first['distribution']);
        final sellers = _rows(first['top_sellers']);
        final usage = _rows(first['material_usage']);
        final cashFlow = _rows(first['cash_flow']);
        final trends = snapshot.data!.skip(1).toList();
        final risks = context
            .watch<InventoryProvider>()
            .stockRisks
            .where((r) => r.level != StockRiskLevel.normal)
            .toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'สรุปวันนี้อยู่ด้านบน แตะหมวดเพื่อเปิดดูรายละเอียด',
                ),
              ),
              if (context.watch<AuthProvider>().isManager)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersPage(),
                        ),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('จัดการบัญชีผู้ใช้'),
                    ),
                  ),
                ),
              _section(
                title: 'สรุปวันนี้',
                subtitle: 'คำสั่งซื้อ การผลิต การส่ง และยอดขาย',
                initiallyExpanded: true,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metric(
                        'คำสั่งซื้อใหม่',
                        _number(summary['today_orders']).toStringAsFixed(0),
                      ),
                      _metric(
                        'ผลิตแล้ว (หน่วย)',
                        _number(summary['today_produced']).toStringAsFixed(0),
                      ),
                      _metric(
                        'ถึงกำหนดส่ง / ค้างส่ง',
                        _number(summary['due_orders']).toStringAsFixed(0),
                      ),
                      _metric(
                        'ยอดขายที่ส่งแล้ว (บาท)',
                        _number(summary['today_revenue']).toStringAsFixed(2),
                      ),
                    ],
                  ),
                ],
              ),
              _section(
                title: 'สต็อกและแจ้งเตือน',
                subtitle: 'ยอดคงเหลือ ของพร้อมส่ง และวัตถุดิบที่ต้องเติม',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metric(
                        'มูลค่าวัตถุดิบ (บาท)',
                        _number(summary['raw_value']).toStringAsFixed(2),
                      ),
                      _metric(
                        'วัตถุดิบคงเหลือ (หน่วย)',
                        _number(summary['raw_units']).toStringAsFixed(0),
                      ),
                      _metric(
                        'สินค้าสำเร็จรูป (หน่วย)',
                        _number(summary['finished_units']).toStringAsFixed(0),
                      ),
                      _metric(
                        'คำสั่งซื้อคงค้าง',
                        _number(summary['open_orders']).toStringAsFixed(0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'สินค้าพร้อมจัดส่ง',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  _bars(
                    distribution
                        .map(
                          (r) => MapEntry(
                            '${r['name']} (${r['unit']})',
                            _number(r['available']),
                          ),
                        )
                        .toList(),
                    'พร้อมส่ง',
                  ),
                  const Text('จำนวนพร้อมส่ง = คงเหลือ − จำนวนที่จองไว้'),
                  const SizedBox(height: 12),
                  Text(
                    'วัตถุดิบที่ต้องเติม',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (risks.isEmpty) const Text('ไม่มีรายการเตือน'),
                  ...risks.map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.warning_amber,
                        color: r.level == StockRiskLevel.critical
                            ? Colors.red
                            : Colors.orange,
                      ),
                      title: Text(r.item.name),
                      subtitle: Text(
                        '${r.level == StockRiskLevel.critical ? "วิกฤต" : "ใกล้ถึงจุดสั่งซื้อ"}: คงเหลือ ${r.item.currentQuantity.toStringAsFixed(2)} ${r.item.unit}; '
                        'สำรอง ${r.safetyStock.toStringAsFixed(2)}, จุดสั่งซื้อ ${r.reorderPoint.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ใช้วัตถุดิบย้อนหลัง $_days วัน',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (usage.isEmpty)
                    const Text('ยังไม่มีการใช้วัตถุดิบในช่วงนี้'),
                  _bars(
                    usage
                        .map(
                          (r) => MapEntry(
                            '${r['name']} (${r['unit']})',
                            _number(r['quantity']),
                          ),
                        )
                        .toList(),
                    'ใช้ไป',
                  ),
                ],
              ),
              _section(
                title: 'ยอดซื้อและต้นทุน',
                subtitle: 'ยอดซื้อ-ขายและราคาซื้อขวดในช่วง $_days วัน',
                children: [
                  _CashFlowChart(cashFlow),
                  const SizedBox(height: 12),
                  Text(
                    'ราคาซื้อขวด',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Text('อ้างอิงจากใบรับสินค้าที่บันทึกในแอป'),
                  if (prices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('ยังไม่มีประวัติซื้อขวดในช่วงนี้'),
                    )
                  else
                    _PurchasePriceChart(prices),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PurchaseReceiptsPage(),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('บันทึก / ดูใบรับสินค้า'),
                  ),
                  ...prices.map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${r['item_name']} - ${_number(r['unit_price']).toStringAsFixed(2)} บาท / หน่วย',
                      ),
                      subtitle: Text(
                        '${r['purchased_at']} - ${r['supplier']} - ${r['reference']}\nรับสินค้า ${r['quantity']} หน่วย',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ),
              _section(
                title: 'ยอดขายและการผลิต',
                subtitle:
                    'ยอดจัดส่ง สินค้าขายดี และรายละเอียดรายวันในช่วง $_days วัน',
                children: [
                  Text(
                    'ยอดขายจากรายการที่จัดส่งแล้ว: ${_number(summary['period_revenue']).toStringAsFixed(2)} บาท',
                  ),
                  const SizedBox(height: 8),
                  _bars([
                    MapEntry(
                      'ผลิตแล้ว',
                      trends.fold<double>(
                        0,
                        (s, r) => s + _number(r['produced']),
                      ),
                    ),
                    MapEntry(
                      'จัดส่งแล้ว',
                      trends.fold<double>(
                        0,
                        (s, r) => s + _number(r['dispatched']),
                      ),
                    ),
                  ], 'หน่วย'),
                  const SizedBox(height: 12),
                  Text(
                    'สินค้าขายดี',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (sellers.isEmpty) const Text('ยังไม่มียอดขายในช่วงนี้'),
                  ...sellers.map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r['name']}'),
                      subtitle: Text('${r['quantity']} ${r['unit']}'),
                      trailing: Text(
                        '${_number(r['revenue']).toStringAsFixed(2)} บาท',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'รายละเอียดรายวัน',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ...trends.map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r['day']}'),
                      subtitle: Text(
                        'ผลิต ${r['produced']} • จัดส่ง ${r['dispatched']}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart(this.rows);

  final List<Map<String, Object?>> rows;
  static const salesColor = Color(0xFF0877C9);
  static const purchaseColor = Color(0xFFFF8A34);

  @override
  Widget build(BuildContext context) {
    double amount(Map<String, Object?> row, String key) =>
        (row[key] as num?)?.toDouble() ?? 0;
    final maxAmount = rows.fold<double>(
      0,
      (value, row) => math.max(
        value,
        math.max(amount(row, 'sales'), amount(row, 'purchases')),
      ),
    );
    if (maxAmount == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('ยังไม่มีรายการซื้อขายในช่วงนี้'),
        ),
      );
    }
    final salesTotal = rows.fold<double>(
      0,
      (sum, row) => sum + amount(row, 'sales'),
    );
    final purchaseTotal = rows.fold<double>(
      0,
      (sum, row) => sum + amount(row, 'purchases'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  'ขาย ${salesTotal.toStringAsFixed(0)} บาท',
                  style: TextStyle(
                    color: salesColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ซื้อ ${purchaseTotal.toStringAsFixed(0)} บาท',
                  style: TextStyle(
                    color: purchaseColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: rows.map((row) {
                  final day = row['day'] as String;
                  final sales = amount(row, 'sales');
                  final purchases = amount(row, 'purchases');
                  Widget bar(double value, Color color) => Container(
                    width: 13,
                    height: math.max(2, value / maxAmount * 130),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  );
                  return Tooltip(
                    message:
                        '$day\nขาย ${sales.toStringAsFixed(2)} บาท\n'
                        'ซื้อ ${purchases.toStringAsFixed(2)} บาท',
                    child: SizedBox(
                      width: 47,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 130,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                bar(sales, salesColor),
                                const SizedBox(width: 3),
                                bar(purchases, purchaseColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            day.substring(8),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            const Text('วันที่ของเดือน • แตะแท่งเพื่อดูยอดรายวัน'),
          ],
        ),
      ),
    );
  }
}

class _PurchasePriceChart extends StatelessWidget {
  final List<Map<String, Object?>> rows;
  const _PurchasePriceChart(this.rows);
  static const colors = {
    'PET_350': Colors.teal,
    'PET_600': Colors.blue,
    'PET_1500': Colors.orange,
  };
  @override
  Widget build(BuildContext context) {
    final maxPrice = rows.fold<double>(
      1,
      (s, r) => math.max(s, (r['unit_price'] as num).toDouble()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('บาท / หน่วย: 0 ถึง ${maxPrice.toStringAsFixed(2)}'),
        SizedBox(
          height: 170,
          width: double.infinity,
          child: CustomPaint(painter: _PricePainter(rows, maxPrice)),
        ),
        const Text('เรียงตามวันที่ซื้อ'),
        Wrap(
          spacing: 12,
          children: colors.entries
              .map((e) => Text(e.key, style: TextStyle(color: e.value)))
              .toList(),
        ),
      ],
    );
  }
}

class _PricePainter extends CustomPainter {
  final List<Map<String, Object?>> rows;
  final double maxPrice;
  _PricePainter(this.rows, this.maxPrice);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;
    const pad = 10.0;
    final height = size.height - 2 * pad;
    final width = size.width - 2 * pad;
    canvas.drawLine(Offset(pad, pad), Offset(pad, size.height - pad), paint);
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(size.width - pad, size.height - pad),
      paint,
    );
    for (final series in _PurchasePriceChart.colors.entries) {
      Offset? previous;
      for (var i = 0; i < rows.length; i++) {
        if (rows[i]['item_code'] != series.key) continue;
        final point = Offset(
          pad + (rows.length == 1 ? width / 2 : i * width / (rows.length - 1)),
          size.height -
              pad -
              (rows[i]['unit_price'] as num).toDouble() / maxPrice * height,
        );
        paint
          ..color = series.value
          ..strokeWidth = 2;
        if (previous != null) canvas.drawLine(previous, point, paint);
        canvas.drawCircle(point, 4, paint);
        previous = point;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PricePainter oldDelegate) =>
      oldDelegate.rows != rows;
}
