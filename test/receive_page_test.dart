import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:water_world/models.dart';
import 'package:water_world/providers/inventory_provider.dart';
import 'package:water_world/screens/receive_page.dart';

void main() {
  testWidgets('เพิ่มวัตถุดิบหลายรายการและเตรียมบันทึกพร้อมกัน', (tester) async {
    final provider = InventoryProvider()
      ..raw = [
        const Item(
          code: 'PET_350',
          name: 'ขวดน้ำ 350 ml',
          itemType: 'raw',
          unit: 'ขวด',
          currentQuantity: 100,
        ),
        const Item(
          code: 'FILM_600',
          name: 'ฟิล์ม 600',
          itemType: 'raw',
          unit: 'ม้วน',
          currentQuantity: 20,
        ),
      ];

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ReceivePage()),
      ),
    );

    expect(find.text('รายการ 1'), findsOneWidget);
    await tester.tap(find.text('เพิ่มสินค้า'));
    await tester.pumpAndSettle();

    expect(find.text('รายการ 1'), findsOneWidget);
    expect(find.text('รายการ 2'), findsOneWidget);
    expect(find.text('บันทึกรับเข้าทั้งหมด (2 รายการ)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '5');
    await tester.enterText(find.byType(TextField).at(2), '3');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'บันทึกรับเข้าทั้งหมด (2 รายการ)'),
    );
    expect(saveButton.onPressed, isNotNull);
  });
}
