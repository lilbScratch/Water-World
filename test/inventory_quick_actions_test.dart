import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:water_world/models.dart';
import 'package:water_world/providers/inventory_provider.dart';
import 'package:water_world/screens/inventory_page.dart';

void main() {
  testWidgets('small phone can open stock change and see projected balance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = InventoryProvider()
      ..raw = [
        const Item(
          code: 'FILM_600',
          name: 'ฟิล์ม 600',
          itemType: 'raw',
          unit: 'ม้วน',
          currentQuantity: 10,
        ),
      ];
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: InventoryPage()),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('รับเข้าสต็อก'), findsOneWidget);
    await tester.tap(find.text('ฟิล์ม 600'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, '5');
    await tester.pump();
    expect(find.text('หลังบันทึก: 15 ม้วน'), findsOneWidget);
  });
}
