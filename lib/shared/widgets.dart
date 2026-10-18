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
    messenger.showSnackBar(SnackBar(content: Text(msg)));
    return true;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: errColor),
    );
    return false;
  }
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

InputDecoration inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}
