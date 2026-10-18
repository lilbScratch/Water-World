import 'package:flutter/material.dart';
import 'stock_action_form.dart';

class DispatchPage extends StatelessWidget {
  const DispatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StockActionForm(
      title: 'จ่ายสินค้าออก',
      action: StockAction.dispatch,
    );
  }
}
