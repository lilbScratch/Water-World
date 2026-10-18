part of 'b2b_page.dart';

class _B2BOrderDialog extends StatefulWidget {
  final List<Map<String, Object?>> customers;
  final List<Item> products;
  final StockRepository repo;
  const _B2BOrderDialog(this.customers, this.products, this.repo);
  @override
  State<_B2BOrderDialog> createState() => _B2BOrderDialogState();
}

class _B2BOrderDialogState extends State<_B2BOrderDialog> {
  final _key = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _notes = TextEditingController();
  late final Map<String, TextEditingController> _qty;
  late final Map<String, TextEditingController> _prices;
  int? _customer;
  DateTime _delivery = DateTime.now().add(const Duration(days: 7));
  OrderPlan? _plan;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _customer = (widget.customers.first['id'] as num).toInt();
    _qty = {
      for (final p in widget.products) p.code: TextEditingController(text: '0'),
    };
    _prices = {
      for (final p in widget.products)
        p.code: TextEditingController(text: '0.00'),
    };
  }

  @override
  void dispose() {
    for (final c in [_search, _notes, ..._qty.values, ..._prices.values]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, Object?>> _lines() => widget.products
      .where((p) => (double.tryParse(_qty[p.code]!.text) ?? 0) > 0)
      .map(
        (p) => <String, Object?>{
          'item_code': p.code,
          'quantity': double.parse(_qty[p.code]!.text),
          'unit_price': double.parse(_prices[p.code]!.text),
        },
      )
      .toList();
  Future<void> _check() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _plan = null;
    });
    try {
      final plan = await widget.repo.precheckB2BOrder(
        _lines(),
        deliveryDate: _delivery,
      );
      if (mounted) setState(() => _plan = plan);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed(String _) => setState(() => _plan = null);
  @override
  Widget build(BuildContext context) {
    final search = _search.text.trim().toLowerCase();
    final customers = widget.customers
        .where(
          (c) => '${c['name']} ${c['contact_person']} ${c['phone']}'
              .toLowerCase()
              .contains(search),
        )
        .toList();
    return AlertDialog(
      title: const Text('สร้างคำสั่งซื้อขายส่ง'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _search,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'ค้นหาชื่อลูกค้าหรือเบอร์โทรศัพท์',
                  ),
                  onChanged: (_) => setState(() {
                    final matches = widget.customers
                        .where(
                          (c) =>
                              '${c['name']} ${c['contact_person']} ${c['phone']}'
                                  .toLowerCase()
                                  .contains(_search.text.trim().toLowerCase()),
                        )
                        .toList();
                    if (!matches.any((c) => c['id'] == _customer)) {
                      _customer = matches.isEmpty
                          ? null
                          : (matches.first['id'] as num).toInt();
                    }
                  }),
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('customer-$_customer-${customers.length}'),
                  initialValue: _customer,
                  isExpanded: true,
                  items: customers
                      .map(
                        (c) => DropdownMenuItem(
                          value: (c['id'] as num).toInt(),
                          child: Text('${c['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _customer = v),
                  decoration: const InputDecoration(labelText: 'ลูกค้า'),
                  validator: (v) => v == null ? 'กรุณาเลือกลูกค้า' : null,
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _delivery,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (mounted && date != null) {
                            setState(() {
                              _delivery = date;
                              _plan = null;
                            });
                          }
                        },
                  child: Text('กำหนดส่ง: ${dateOnly(_delivery)}'),
                ),
                ...widget.products.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.name}: พร้อมใช้ ${p.availableQuantity.toStringAsFixed(2)} ${p.unit}',
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qty[p.code],
                                enabled: !_busy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: _changed,
                                decoration: InputDecoration(
                                  labelText: 'จำนวน (${p.unit})',
                                ),
                                validator: (s) {
                                  final n = double.tryParse(s ?? '');
                                  return n == null || !n.isFinite || n < 0
                                      ? 'กรุณาระบุจำนวนตั้งแต่ 0 ขึ้นไป'
                                      : null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _prices[p.code],
                                enabled: !_busy,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: _changed,
                                decoration: const InputDecoration(
                                  labelText: 'ราคาขายต่อหน่วย (บาท)',
                                ),
                                validator: (s) {
                                  final n = double.tryParse(s ?? '');
                                  return n == null || !n.isFinite || n < 0
                                      ? 'กรุณาระบุราคาให้ถูกต้อง'
                                      : null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_plan != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _plan!.status,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ..._plan!.products.map(
                            (p) => Text(
                              '${p.product.name}: ใช้สินค้าคงเหลือ ${p.fromStock}, ผลิตเพิ่ม ${p.toProduce} ${p.product.unit}',
                            ),
                          ),
                          ..._plan!.materials.map(
                            (m) => Text(
                              '${m.material.name}: ต้องใช้ ${m.requiredQuantity.toStringAsFixed(2)}, '
                              'พร้อมใช้ ${m.material.availableQuantity.toStringAsFixed(2)}, ขาด ${m.shortage.toStringAsFixed(2)} ${m.material.unit}; ระยะเวลาจัดซื้อ ${m.material.leadTimeDays} วัน',
                            ),
                          ),
                          if (_plan!.missingRecipes.isNotEmpty)
                            Text(
                              'กรุณากำหนดสูตรการผลิตก่อน: ${_plan!.missingRecipes.join(', ')}',
                            ),
                          if (_plan!.missingRecipes.isEmpty)
                            Text(
                              'คาดว่าพร้อมส่งได้เร็วที่สุด: ${dateOnly(_plan!.earliestDelivery)}',
                            ),
                          const Text(
                            'ระยะเวลาประเมิน = ระยะเวลาจัดซื้อวัตถุดิบที่ขาดนานที่สุด + ระยะเวลาผลิตสินค้าที่นานที่สุด ยังไม่รวมการจัดตารางกำลังผลิตและการขนส่ง',
                          ),
                          if (!_plan!.canConfirm)
                            const Text(
                              'บันทึกเป็นฉบับร่างได้ แต่ต้องมีสต็อก สูตรการผลิต และกำหนดส่งที่เหมาะสมก่อนยืนยันคำสั่งซื้อ',
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _check,
          child: Text(_busy ? 'กำลังตรวจสอบ…' : 'ตรวจสอบความพร้อม'),
        ),
        FilledButton(
          onPressed: _busy || _plan == null
              ? null
              : () {
                  if (!_key.currentState!.validate()) return;
                  Navigator.pop(context, <String, Object?>{
                    'customer_id': _customer!,
                    'items': _lines(),
                    'delivery_date': _delivery,
                    'notes': _notes.text,
                  });
                },
          child: const Text('บันทึกฉบับร่าง'),
        ),
      ],
    );
  }
}
