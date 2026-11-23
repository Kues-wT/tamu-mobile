// Plus and minus buttons for price and stock (FR2, examiner feedback).
//
// Run with:  flutter test test/stepper_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamu_mobile/widgets/number_stepper.dart';

Future<TextEditingController> _pump(
    WidgetTester tester, String start, double step, int decimals) async {
  final controller = TextEditingController(text: start);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: NumberStepperField(
        controller: controller,
        step: step,
        decimals: decimals,
        field: TextFormField(controller: controller),
      ),
    ),
  ));
  return controller;
}

void main() {
  testWidgets('+ adds one to the stock', (tester) async {
    final c = await _pump(tester, '20', 1, 0);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(c.text, '21');
  });

  testWidgets('- never goes below zero', (tester) async {
    final c = await _pump(tester, '1', 1, 0);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(c.text, '0');
  });

  testWidgets('price moves in RM 0.50 steps', (tester) async {
    final c = await _pump(tester, '3.50', 0.5, 2);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(c.text, '4.00');
  });

  testWidgets('an empty field starts from zero', (tester) async {
    final c = await _pump(tester, '', 1, 0);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(c.text, '1');
  });
}
