import 'package:flutter/material.dart';
import 'stock_action_form.dart';

class AdjustPage extends StatelessWidget {
  const AdjustPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StockActionForm(
      title: 'ปรับยอดคงเหลือ',
      action: StockAction.adjust,
    );
  }
}
