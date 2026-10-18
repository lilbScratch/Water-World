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
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
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
              if (context.watch<AuthProvider>().isManager)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                    ),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('จัดการบัญชีผู้ใช้'),
                  ),
                ),
              _heading('สรุปการดำเนินงานวันนี้'),
              Wrap(
                spacing: 4,
                children: [
                  _metric(
                    'คำสั่งซื้อใหม่วันนี้',
                    _number(summary['today_orders']).toStringAsFixed(0),
                  ),
                  _metric(
                    'ยอดผลิตวันนี้ (หน่วย)',
                    _number(summary['today_produced']).toStringAsFixed(0),
                  ),
                  _metric(
                    'ถึงกำหนดส่ง / ค้างส่ง',
                    _number(summary['due_orders']).toStringAsFixed(0),
                  ),
                  _metric(
                    'ยอดขายที่จัดส่งแล้ววันนี้ (บาท)',
                    _number(summary['today_revenue']).toStringAsFixed(2),
                  ),
                ],
              ),
              _heading('สต็อกปัจจุบัน'),
              Wrap(
                spacing: 4,
                children: [
                  _metric(
                    'มูลค่าวัตถุดิบคงเหลือ (บาท)',
                    _number(summary['raw_value']).toStringAsFixed(2),
                  ),
                  _metric(
                    'วัตถุดิบคงเหลือ (หน่วย)',
                    _number(summary['raw_units']).toStringAsFixed(0),
                  ),
                  _metric(
                    'สินค้าสำเร็จรูปคงเหลือ (หน่วย)',
                    _number(summary['finished_units']).toStringAsFixed(0),
                  ),
                  _metric(
                    'คำสั่งซื้อคงค้าง',
                    _number(summary['open_orders']).toStringAsFixed(0),
                  ),
                ],
              ),
              _heading('สินค้าพร้อมจัดส่งตามขนาด'),
              _bars(
                distribution
                    .map(
                      (r) => MapEntry(
                        '${r['name']} (${r['unit']})',
                        _number(r['available']),
                      ),
                    )
                    .toList(),
                'พร้อมใช้',
              ),
              const Text('ยอดพร้อมส่ง = คงเหลือ − สำรอง'),
              _heading('วัตถุดิบที่ต้องเติม'),
              if (risks.isEmpty) const Text('ไม่มีรายการแจ้งเตือน'),
              ...risks.map(
                (r) => Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_amber,
                      color: r.level == StockRiskLevel.critical
                          ? Colors.red
                          : Colors.orange,
                    ),
                    title: Text(r.item.name),
                    subtitle: Text(
                      '${r.level == StockRiskLevel.critical ? "วิกฤต" : "ใกล้ถึงจุดสั่งซื้อ"}: คงเหลือ ${r.item.currentQuantity.toStringAsFixed(2)} ${r.item.unit}; '
                      'สต็อกสำรอง ${r.safetyStock.toStringAsFixed(2)}, จุดสั่งซื้อ ${r.reorderPoint.toStringAsFixed(2)}',
                    ),
                  ),
                ),
              ),
              _heading('ยอดขายและการผลิตย้อนหลัง $_days วัน'),
              Text(
                'ยอดขายจากคำสั่งซื้อที่จัดส่งแล้ว: ${_number(summary['period_revenue']).toStringAsFixed(2)} บาท',
              ),
              const Text('ยอดขายนับจากคำสั่งซื้อที่จัดส่งแล้ว'),
              _bars([
                MapEntry(
                  'ผลิตแล้ว',
                  trends.fold<double>(0, (s, r) => s + _number(r['produced'])),
                ),
                MapEntry(
                  'จัดส่งแล้ว',
                  trends.fold<double>(
                    0,
                    (s, r) => s + _number(r['dispatched']),
                  ),
                ),
              ], 'หน่วย'),
              _heading('สินค้าขายดี'),
              _bars(
                sellers
                    .map((r) => MapEntry('${r['name']}', _number(r['revenue'])))
                    .toList(),
                'บาท',
              ),
              if (sellers.isEmpty) const Text('ยังไม่มียอดขายในช่วงนี้'),
              ...sellers.map(
                (r) => ListTile(
                  title: Text('${r['name']}'),
                  subtitle: Text('${r['quantity']} ${r['unit']}'),
                  trailing: Text(
                    '${_number(r['revenue']).toStringAsFixed(2)} บาท',
                  ),
                ),
              ),
              _heading('ประวัติราคาซื้อขวด ย้อนหลัง $_days วัน'),
              const Text('ราคาจากใบรับสินค้าจริง • 1 จุดต่อรายการรับ'),
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
                  title: Text(
                    '${r['item_name']} - ${_number(r['unit_price']).toStringAsFixed(2)} บาท / หน่วย',
                  ),
                  subtitle: Text(
                    '${r['purchased_at']} - ${r['supplier']} - ${r['reference']}\nรายการรับสินค้า #${r['id']}: ${r['quantity']} หน่วย',
                  ),
                  isThreeLine: true,
                ),
              ),
              _heading('ยอดใช้วัตถุดิบย้อนหลัง $_days วัน'),
              if (usage.isEmpty) const Text('ยังไม่มีการใช้วัตถุดิบในช่วงนี้'),
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
              _heading('รายละเอียดการผลิตและการจัดส่งรายวัน'),
              ...trends.map(
                (r) => ListTile(
                  title: Text('${r['day']}'),
                  subtitle: Text(
                    'ผลิต ${r['produced']} - จัดส่ง ${r['dispatched']}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
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
