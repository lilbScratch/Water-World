// Reusable input, save-feedback, and message widgets.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final qtyFmt = NumberFormat('#,##0.##', 'th');

/// ช่องกรอกตัวเลข (รองรับทศนิยม)
Widget numberInput(TextEditingController controller, String label) =>
    TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );

/// รัน action แล้วแสดง snackbar ภาษาไทยตามผลลัพธ์
/// คืนค่า true เมื่อสำเร็จ (ใช้ตัดสินใจปิดหน้าฟอร์ม)
Future<bool> trySave(
  BuildContext context,
  Future<String> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final errColor = Theme.of(context).colorScheme.error;
  try {
    final msg = await action();
    messenger.showSnackBar(appSnackBar(Text(msg)));
    return true;
  } catch (e) {
    messenger.showSnackBar(appSnackBar(Text('$e'), backgroundColor: errColor));
    return false;
  }
}

SnackBar appSnackBar(Widget content, {Color? backgroundColor}) => SnackBar(
  content: content,
  backgroundColor: backgroundColor,
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 3),
);

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(appSnackBar(Text(message)));
}

InputDecoration inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}
