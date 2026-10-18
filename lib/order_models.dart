import 'models.dart';

class ProductPlan {
  final Item product;
  final double requested;
  final double fromStock;
  final double toProduce;
  const ProductPlan(
    this.product,
    this.requested,
    this.fromStock,
    this.toProduce,
  );
}

class MaterialPlan {
  final Item material;
  final double requiredQuantity;
  const MaterialPlan(this.material, this.requiredQuantity);
  double get shortage => (requiredQuantity - material.availableQuantity)
      .clamp(0, double.infinity)
      .toDouble();
}

class OrderPlan {
  final List<ProductPlan> products;
  final List<MaterialPlan> materials;
  final List<String> missingRecipes;
  final DateTime earliestDelivery;
  final DateTime? requestedDelivery;
  const OrderPlan({
    required this.products,
    required this.materials,
    required this.missingRecipes,
    required this.earliestDelivery,
    this.requestedDelivery,
  });
  bool get needsProduction => products.any((p) => p.toProduce > 0);
  bool get materialsReady => materials.every((m) => m.shortage == 0);
  bool get dateReady =>
      requestedDelivery == null ||
      !requestedDelivery!.isBefore(earliestDelivery);
  bool get canConfirm => missingRecipes.isEmpty && materialsReady && dateReady;
  String get status => missingRecipes.isNotEmpty
      ? 'ยังไม่ได้กำหนดสูตรการผลิต'
      : !materialsReady
      ? 'วัตถุดิบไม่เพียงพอ'
      : !dateReady
      ? 'กำหนดส่งเร็วกว่าระยะเวลาที่ประเมิน'
      : needsProduction
      ? 'วัตถุดิบพร้อมสำหรับการผลิต'
      : 'พร้อมจัดส่ง';
}

String dateOnly(DateTime date) => date.toIso8601String().substring(0, 10);
