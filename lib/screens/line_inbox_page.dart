// Reviews and resolves stock-change requests received through LINE.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/line_bridge_client.dart';
import '../models.dart';
import '../providers/inventory_provider.dart';
import '../shared/widgets.dart';

class LineInboxPage extends StatefulWidget {
  const LineInboxPage({super.key});

  @override
  State<LineInboxPage> createState() => _LineInboxPageState();
}

class _LineInboxPageState extends State<LineInboxPage> {
  final _url = TextEditingController(
    text: const String.fromEnvironment('STOCK_BRIDGE_URL'),
  );
  final _token = TextEditingController();
  LineBridgeClient? _client;
  List<LineStockCommand> _pending = [];
  bool _loading = false;
  String? _busyId;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = LineBridgeClient(_url.text, _token.text);
      final inventory = context.read<InventoryProvider>();
      await client.syncCatalog([...inventory.raw, ...inventory.finished]);
      final commands = await client.pending();
      if (!mounted) return;
      setState(() {
        _client = client;
        _pending = commands;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เชื่อมต่อ LINE ไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(LineStockCommand command, bool apply) async {
    final client = _client;
    if (client == null) return;
    setState(() => _busyId = command.id);
    try {
      if (apply) {
        final inventory = context.read<InventoryProvider>();
        await inventory.repo.applyLineCommand(
          command.id,
          command.code,
          command.delta,
        );
        await inventory.refresh();
      }
      await client.resolve(command.id, apply ? 'applied' : 'rejected');
      if (!mounted) return;
      setState(() => _pending.removeWhere((entry) => entry.id == command.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apply ? 'บันทึกสต็อกแล้ว' : 'ปฏิเสธคำขอแล้ว')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ดำเนินการไม่สำเร็จ: $error')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final byCode = {
      for (final item in [...inventory.raw, ...inventory.finished])
        item.code: item,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('คำขอปรับสต็อกจาก LINE')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'ข้อความจากกลุ่มจะรอยืนยันที่นี่ ก่อนเปลี่ยนยอดสต็อกในเครื่องนี้',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL เซิร์ฟเวอร์ LINE',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'รหัสเชื่อมต่อ (ไม่บันทึกในเครื่อง)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.sync),
            label: Text(_loading ? 'กำลังโหลด...' : 'เชื่อมต่อและโหลดคำขอ'),
          ),
          const SizedBox(height: 20),
          if (_client != null && _pending.isEmpty)
            const Text('ไม่มีคำขอที่รอดำเนินการ'),
          for (final command in _pending)
            _commandCard(command, byCode[command.code]),
        ],
      ),
    );
  }

  Widget _commandCard(LineStockCommand command, Item? item) {
    final next = item == null ? null : item.currentQuantity + command.delta;
    final valid = item != null && next != null && next >= item.reservedQuantity;
    final busy = _busyId != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              command.rawText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${command.itemName} (${command.code})'),
            Text(
              'เปลี่ยน ${command.delta > 0 ? '+' : ''}${qtyFmt.format(command.delta)} ${item?.unit ?? ''}',
            ),
            if (item != null)
              Text(
                'ยอดปัจจุบัน ${qtyFmt.format(item.currentQuantity)} → ${qtyFmt.format(next!)} ${item.unit}',
              ),
            if (!valid)
              const Text(
                'สินค้าไม่อยู่ในเครื่องนี้ หรือจำนวนที่จะเบิกเกินยอดที่ใช้ได้',
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _resolve(command, false),
                    child: const Text('ปฏิเสธ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy || !valid
                        ? null
                        : () => _resolve(command, true),
                    child: Text(
                      _busyId == command.id ? 'กำลังบันทึก...' : 'ยืนยัน',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
