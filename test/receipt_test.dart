// Online payment step and receipt (FR5).
//
// Run with:  flutter test test/receipt_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamu_mobile/api_service.dart';
import 'package:tamu_mobile/screens/receipt_screen.dart';

Order _paidOrder({String status = 'pending'}) => Order(
      id: 7,
      productId: 3,
      buyerId: 2,
      buyerName: 'Hermione',
      quantity: 4,
      totalPrice: 18.0,
      status: status,
      createdAt: DateTime(2026, 11, 1, 14, 30),
      productName: 'Kelapa',
      farmerName: 'Puan Siti',
      paymentMethod: 'mock_online',
      paymentRef: 'PAY-261101-A1B2C3',
      paidAt: DateTime(2026, 11, 1, 14, 31),
    );

void main() {
  testWidgets('receipt shows the amount, receipt number and farmer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(order: _paidOrder())));

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('RM 18.00'), findsOneWidget);
    expect(find.text('PAY-261101-A1B2C3'), findsOneWidget);
    expect(find.text('Puan Siti'), findsOneWidget);
    expect(find.text('#TAMU-0007'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('a cancelled paid order shows as refunded', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReceiptScreen(order: _paidOrder(status: 'cancelled'))),
    );

    expect(find.text('Payment refunded'), findsOneWidget);
    expect(find.text('Refunded'), findsOneWidget);
  });

  testWidgets('pay sheet processes the payment and closes with success',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showModalBottomSheet<bool>(
              context: context,
              builder: (_) =>
                  const OnlinePaySheet(amount: 18, farmerName: 'Puan Siti'),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Pay to Puan Siti'), findsOneWidget);
    expect(find.text('Mock payment'), findsOneWidget);

    await tester.tap(find.text('Pay now · RM 18.00'));
    await tester.pump();
    expect(find.text('Processing payment...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancelling the pay sheet does not pay', (tester) async {
    bool? result = true;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showModalBottomSheet<bool>(
              context: context,
              builder: (_) =>
                  const OnlinePaySheet(amount: 18, farmerName: 'Puan Siti'),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
