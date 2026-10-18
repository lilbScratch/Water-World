import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/stock_repository.dart';
import '../models.dart';

class InventoryProvider extends ChangeNotifier {
  final StockRepository repo;

  InventoryProvider({StockRepository? repo}) : repo = repo ?? StockRepository();

  List<Item> raw = [];
  List<Item> finished = [];
  List<RecipeLine> recipes = [];
  List<StockTx> historyItems = [];
  List<StockRisk> stockRisks = [];

  String historyFilter = 'all';
  bool loading = false;
  int revision = 0;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();

    try {
      raw = await repo.items(type: 'raw');
      finished = await repo.items(type: 'finished');
      recipes = await repo.allRecipes();

      await refreshStockRisks(notify: false);

      historyItems = await repo.history(filter: historyFilter);
    } finally {
      loading = false;
      revision++;
      notifyListeners();
    }
  }

  Future<void> refreshStockRisks({bool notify = true}) async {
    final items = await repo.items(type: 'raw');
    final results = <StockRisk>[];

    for (final item in items) {
      final stats = await repo.consumptionStats(item.code, days: 30);

      final average = stats['average'] ?? 0;
      final deviation = stats['stddev'] ?? 0;

      // Safety Stock = Z × SD × sqrt(Lead Time)
      final calculatedSafety =
          item.serviceLevelZ *
          deviation *
          math.sqrt(item.leadTimeDays.toDouble());

      final safety = item.safetyStock > 0 ? item.safetyStock : calculatedSafety;

      // ใช้จุดสั่งซื้อที่กำหนดเอง หากเป็น 0 จะคำนวณอัตโนมัติ
      final calculatedReorder = average * item.leadTimeDays + safety;

      final reorder = item.minQuantity > 0
          ? item.minQuantity
          : calculatedReorder;

      // ปริมาณเป้าหมายสำรอง
      final target = average * item.targetDays + safety;

      final suggested = math.max(0.0, target - item.currentQuantity);

      final StockRiskLevel level;

      if (item.currentQuantity <= safety) {
        level = StockRiskLevel.critical;
      } else if (item.currentQuantity <= reorder) {
        level = StockRiskLevel.warning;
      } else {
        level = StockRiskLevel.normal;
      }

      results.add(
        StockRisk(
          item: item,
          averageDailyUsage: average,
          standardDeviation: deviation,
          safetyStock: safety,
          reorderPoint: reorder,
          targetStock: target,
          suggestedOrderQuantity: suggested,
          level: level,
        ),
      );
    }

    stockRisks = results;

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> loadHistory([String? filter]) async {
    if (filter != null) {
      historyFilter = filter;
    }

    historyItems = await repo.history(filter: historyFilter);

    notifyListeners();
  }

  Future<void> receive(String code, double quantity, {String note = ''}) async {
    await repo.receive(code, quantity, note: note);
    await refresh();
  }

  Future<void> produce(String code, double quantity, {String note = ''}) async {
    await repo.produce(code, quantity, note: note);
    await refresh();
  }

  Future<void> dispatch(
    String code,
    double quantity, {
    String note = '',
  }) async {
    await repo.dispatch(code, quantity, note: note);
    await refresh();
  }

  Future<void> adjust(
    String code,
    double newBalance, {
    String note = '',
  }) async {
    await repo.adjust(code, newBalance, note: note);
    await refresh();
  }

  Future<void> saveStockPolicy({
    required String code,
    required int leadTimeDays,
    required int targetDays,
    required double serviceLevelZ,
    double? safetyStock,
    double? minQuantity,
  }) async {
    await repo.saveStockPolicy(
      code: code,
      leadTimeDays: leadTimeDays,
      targetDays: targetDays,
      serviceLevelZ: serviceLevelZ,
      safetyStock: safetyStock,
      minQuantity: minQuantity,
    );

    await refresh();
  }

  // สร้างใบสั่งซื้อและบันทึกลงฐานข้อมูล
  Future<int> createPurchaseOrder(List<Map<String, Object?>> items) async {
    final id = await repo.createPurchaseOrder(items);
    await refreshStockRisks();
    return id;
  }

  // อ่านรายการสั่งซื้อทั้งหมดจากฐานข้อมูล SQLite
  Future<List<Map<String, Object?>>> purchaseOrders() async {
    return repo.purchaseOrders();
  }
}
