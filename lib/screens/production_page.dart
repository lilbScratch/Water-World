import 'package:flutter/material.dart';
import 'stock_action_form.dart';

class ProductionPage extends StatelessWidget {
  const ProductionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StockActionForm(
      title: 'บันทึกการผลิต',
      action: StockAction.produce,
    );
  }
}
