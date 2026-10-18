part of 'stock_repository.dart';

extension AnalyticsOperations on StockRepository {
  Future<List<Map<String, Object?>>> dashboardStats({int days = 7}) async {
    if (![1, 7, 30].contains(days)) throw ArgumentError('Use 1, 7 or 30 days.');
    final db = await appDb.database;
    // All date windows use local calendar dates, matching stored receipt dates.
    final now = DateTime.now();
    final today = dateOnly(now);
    final cutoff = dateOnly(
      DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1)),
    );
    final inventory = (await db.rawQuery('''SELECT
      COALESCE(SUM(CASE WHEN item_type IN ('raw','raw_material','วัตถุดิบ') THEN current_quantity * unit_cost ELSE 0 END),0) AS raw_value,
      COALESCE(SUM(CASE WHEN item_type IN ('raw','raw_material','วัตถุดิบ') THEN current_quantity ELSE 0 END),0) AS raw_units,
      COALESCE(SUM(CASE WHEN item_type IN ('finished','finished_good','สินค้าสำเร็จรูป') THEN current_quantity ELSE 0 END),0) AS finished_units
      FROM items''')).single;
    final orders = (await db.rawQuery(
      '''SELECT
      SUM(CASE WHEN date(created_at) = ? THEN 1 ELSE 0 END) AS today_orders,
      SUM(CASE WHEN status IN ('confirmed','awaiting_production') AND (delivery_date IS NULL OR delivery_date <= ?) THEN 1 ELSE 0 END) AS due_orders,
      SUM(CASE WHEN status IN ('draft','confirmed','awaiting_production') THEN 1 ELSE 0 END) AS open_orders
      FROM b2b_orders''',
      [today, today],
    )).single;
    final daily = (await db.rawQuery(
      "SELECT COALESCE(SUM(quantity),0) AS today_produced FROM stock_transactions WHERE tx_type='production_output' AND date(created_at)=?",
      [today],
    )).single;
    final sales = (await db.rawQuery(
      '''SELECT
      COALESCE(SUM(CASE WHEN date(o.fulfilled_at) = ? THEN l.quantity*l.unit_price ELSE 0 END),0) AS today_revenue,
      COALESCE(SUM(l.quantity*l.unit_price),0) AS period_revenue
      FROM b2b_orders o JOIN b2b_order_lines l ON l.order_id=o.id
      WHERE o.status='fulfilled' AND date(o.fulfilled_at) BETWEEN ? AND ?''',
      [today, cutoff, today],
    )).single;
    final distribution = await db.rawQuery(
      '''SELECT code, name, unit,
      MAX(0,current_quantity-reserved_quantity) AS available FROM items
      WHERE item_type IN ('finished','finished_good','สินค้าสำเร็จรูป') ORDER BY code''',
    );
    final prices = await db.rawQuery(
      '''SELECT r.*, i.name AS item_name FROM purchase_receipts r
      JOIN items i ON i.code=r.item_code
      WHERE r.item_code IN ('PET_350','PET_600','PET_1500')
      AND r.purchased_at BETWEEN ? AND ? ORDER BY r.purchased_at, r.id''',
      [cutoff, today],
    );
    final sellers = await db.rawQuery(
      '''SELECT i.name, i.unit, SUM(l.quantity) AS quantity,
      SUM(l.quantity*l.unit_price) AS revenue FROM b2b_order_lines l
      JOIN b2b_orders o ON o.id=l.order_id JOIN items i ON i.code=l.item_code
      WHERE o.status='fulfilled' AND date(o.fulfilled_at) BETWEEN ? AND ?
      GROUP BY i.code ORDER BY quantity DESC''',
      [cutoff, today],
    );
    final usage = await db.rawQuery(
      '''SELECT i.name, i.unit, SUM(-t.quantity) AS quantity
      FROM stock_transactions t JOIN items i ON i.code=t.item_code
      WHERE t.tx_type='production_consume' AND date(t.created_at) BETWEEN ? AND ?
      GROUP BY i.code ORDER BY i.name''',
      [cutoff, today],
    );
    final trends = await db.rawQuery(
      '''SELECT date(t.created_at) AS day,
      SUM(CASE WHEN t.tx_type='production_output' THEN t.quantity ELSE 0 END) AS produced,
      SUM(CASE WHEN t.tx_type IN ('dispatch','b2b_dispatch') THEN -t.quantity ELSE 0 END) AS dispatched,
      SUM(CASE WHEN t.tx_type='production_consume' THEN -t.quantity*i.unit_cost ELSE 0 END) AS material_cost
      FROM stock_transactions t LEFT JOIN items i ON i.code=t.item_code
      WHERE date(t.created_at) BETWEEN ? AND ? GROUP BY date(t.created_at) ORDER BY day''',
      [cutoff, today],
    );
    return [
      {
        'summary': {...inventory, ...orders, ...daily, ...sales},
        'distribution': distribution,
        'purchase_prices': prices,
        'top_sellers': sellers,
        'material_usage': usage,
      },
      ...trends,
    ];
  }
}
