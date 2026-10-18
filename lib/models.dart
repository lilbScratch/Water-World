class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

class Item {
  final int? id;
  final String code;
  final String name;
  final String itemType;
  final String unit;
  final double currentQuantity;
  final double reservedQuantity;
  final int productionLeadDays;
  final double unitCost;

  // ข้อมูลสำหรับระบบ Safety Stock
  final double minQuantity;
  final double safetyStock;
  final int leadTimeDays;
  final int targetDays;
  final double serviceLevelZ;

  const Item({
    this.id,
    required this.code,
    required this.name,
    required this.itemType,
    required this.unit,
    this.currentQuantity = 0,
    this.reservedQuantity = 0,
    this.productionLeadDays = 1,
    this.unitCost = 0,
    this.minQuantity = 0,
    this.safetyStock = 0,
    this.leadTimeDays = 3,
    this.targetDays = 14,
    this.serviceLevelZ = 1.65,
  });

  bool get isRaw => itemType == 'raw';
  double get availableQuantity => currentQuantity - reservedQuantity;

  factory Item.fromMap(Map<String, Object?> map) {
    return Item(
      id: map['id'] as int?,
      code: map['code'] as String,
      name: map['name'] as String,
      itemType: map['item_type'] as String,
      unit: map['unit'] as String,
      currentQuantity: (map['current_quantity'] as num?)?.toDouble() ?? 0,
      reservedQuantity: (map['reserved_quantity'] as num?)?.toDouble() ?? 0,
      productionLeadDays: (map['production_lead_days'] as num?)?.toInt() ?? 1,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
      minQuantity: (map['min_quantity'] as num?)?.toDouble() ?? 0,
      safetyStock: (map['safety_stock'] as num?)?.toDouble() ?? 0,
      leadTimeDays: (map['lead_time_days'] as num?)?.toInt() ?? 3,
      targetDays: (map['target_days'] as num?)?.toInt() ?? 14,
      serviceLevelZ: (map['service_level_z'] as num?)?.toDouble() ?? 1.65,
    );
  }
}

class RecipeLine {
  final int? id;
  final String finishedCode;
  final String rawCode;
  final double quantity;
  final String rawName;
  final String rawUnit;

  const RecipeLine({
    this.id,
    required this.finishedCode,
    required this.rawCode,
    required this.quantity,
    required this.rawName,
    required this.rawUnit,
  });

  factory RecipeLine.fromMap(Map<String, Object?> map) {
    return RecipeLine(
      id: map['id'] as int?,
      finishedCode: map['finished_code'] as String,
      rawCode: map['raw_code'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      rawName: (map['raw_name'] as String?) ?? '',
      rawUnit: (map['raw_unit'] as String?) ?? '',
    );
  }
}

class StockTx {
  final int id;
  final String itemCode;
  final String itemName;
  final String txType;
  final double quantity;
  final double balanceAfter;
  final String note;
  final String createdAt;

  const StockTx({
    required this.id,
    required this.itemCode,
    required this.itemName,
    required this.txType,
    required this.quantity,
    required this.balanceAfter,
    required this.note,
    required this.createdAt,
  });

  factory StockTx.fromMap(Map<String, Object?> map) {
    return StockTx(
      id: map['id'] as int,
      itemCode: map['item_code'] as String,
      itemName: (map['item_name'] as String?) ?? map['item_code'] as String,
      txType: map['tx_type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      note: (map['note'] as String?) ?? '',
      createdAt: map['created_at'] as String,
    );
  }
}

const Map<String, String> kTxLabels = {
  'receive': 'รับเข้า',
  'production_consume': 'ใช้วัตถุดิบผลิต',
  'production_output': 'ผลิตสินค้า',
  'dispatch': 'จ่ายออก',
  'adjust': 'ปรับยอด',
};

const Map<String, String> kHistoryFilters = {
  'all': 'ทั้งหมด',
  'receive': 'รับเข้า',
  'production_consume': 'ใช้ผลิต',
  'production_output': 'ผลิตสินค้า',
  'dispatch': 'จ่ายออก',
  'adjust': 'ปรับยอด',
};

enum StockRiskLevel { normal, warning, critical }

class StockRisk {
  final Item item;
  final double averageDailyUsage;
  final double standardDeviation;
  final double safetyStock;
  final double reorderPoint;
  final double targetStock;
  final double suggestedOrderQuantity;
  final StockRiskLevel level;

  const StockRisk({
    required this.item,
    required this.averageDailyUsage,
    required this.standardDeviation,
    required this.safetyStock,
    required this.reorderPoint,
    required this.targetStock,
    required this.suggestedOrderQuantity,
    required this.level,
  });
}
