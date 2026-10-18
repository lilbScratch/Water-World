import 'package:flutter/material.dart';
import 'stock_action_form.dart';

class ReceivePage extends StatelessWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StockActionForm(
      title: 'รับวัตถุดิบเข้า',
      action: StockAction.receive,
    );
  }
}
