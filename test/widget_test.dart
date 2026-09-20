// Basic smoke test for the TAMU app.
//
// Run with:  flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamu_mobile/main.dart';

void main() {
  testWidgets('Login screen shows the TAMU branding',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TamuApp());

    expect(find.text('TAMU'), findsOneWidget);
    expect(find.text('Farm Fresh. Direct to You.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });
}
