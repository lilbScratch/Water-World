import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';

class PurchaseOrderHistoryPage extends StatefulWidget {
  const PurchaseOrderHistoryPage({super.key});

  @override
  State<PurchaseOrderHistoryPage> createState() =>
      _PurchaseOrderHistoryPageState();
}

class _PurchaseOrderHistoryPageState extends State<PurchaseOrderHistoryPage> {
  late Future<List<Map<String, Object?>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = context.read<InventoryProvider>().purchaseOrders();
  }

  Future<void> _refresh() async {
    setState(_loadOrders);
    await _ordersFuture;
  }

  List<Map<String, dynamic>> _parseItems(Object? value) {
    if (value == null) return [];

    try {
      final decoded = jsonDecode(value.toString());

      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _formatDate(Object? value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(double value) => value.toStringAsFixed(2);

  void _showDetails(Map<String, Object?> order) {
    final items = _parseItems(order['items_json']);
    final id = order['id']?.toString() ?? '-';

    final total = items.fold<double>(
      0,
      (sum, item) =>
          sum + _number(item['quantity']) * _number(item['unit_cost']),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('รายละเอียดใบสั่งซื้อ #$id'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('วันที่: ${_formatDate(order['created_at'])}'),
                Text('สถานะ: ${order['status'] ?? '-'}'),
                const Divider(height: 24),
                if (items.isEmpty)
                  const Text('ไม่พบรายละเอียดสินค้าในใบสั่งซื้อนี้')
                else
                  ...items.map((item) {
                    final name =
                        item['name']?.toString() ?? 'ไม่ระบุชื่อสินค้า';
                    final code = item['code']?.toString() ?? '-';
                    final unit = item['unit']?.toString() ?? '';
                    final quantity = _number(item['quantity']);
                    final unitCost = _number(item['unit_cost']);
                    final subtotal = quantity * unitCost;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('รหัสสินค้า: $code'),
                          Text('จำนวน: ${quantity.toStringAsFixed(2)} $unit'),
                          Text('ราคาต่อหน่วย: ${_money(unitCost)} บาท'),
                          Text('รวม: ${_money(subtotal)} บาท'),
                        ],
                      ),
                    );
                  }),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'รวมทั้งหมด ${_money(total)} บาท',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (items.any((item) => _number(item['unit_cost']) == 0))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'หมายเหตุ: สินค้าบางรายการไม่มีราคาต่อหน่วย '
                      'ยอดรวมจึงอาจยังไม่ครบ',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการสั่งซื้อที่บันทึกไว้'),
        actions: [
          IconButton(
            tooltip: 'โหลดรายการใหม่',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text('โหลดรายการไม่สำเร็จ: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(_loadOrders),
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'ยังไม่มีรายการสั่งซื้อที่บันทึกไว้',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'รายการที่บันทึกจากหน้าสร้างรายการสั่งซื้อ '
                      'จะแสดงที่นี่',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = orders[index];
                final id = order['id']?.toString() ?? '-';
                final items = _parseItems(order['items_json']);
                final status = order['status']?.toString() ?? '-';

                final total = items.fold<double>(
                  0,
                  (sum, item) =>
                      sum +
                      _number(item['quantity']) * _number(item['unit_cost']),
                );

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        id.length > 4 ? id.substring(id.length - 4) : id,
                      ),
                    ),
                    title: Text(
                      'ใบสั่งซื้อ #$id',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('วันที่: ${_formatDate(order['created_at'])}'),
                          Text('สินค้า ${items.length} รายการ'),
                          Text('สถานะ: $status'),
                          Text('ยอดรวม ${_money(total)} บาท'),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    isThreeLine: true,
                    onTap: () => _showDetails(order),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
