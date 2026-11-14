// Online payment (Stripe test mode) and receipt (FR9).
//
// Run with:  flutter test test/receipt_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamu_mobile/api_service.dart';
import 'package:tamu_mobile/screens/payment_screen.dart';
import 'package:tamu_mobile/screens/receipt_screen.dart';

Order _paidOrder({String status = 'pending', String method = 'stripe'}) => Order(
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
      paymentMethod: method,
      paymentStatus: status == 'cancelled' ? 'refunded' : 'paid',
      paymentRef: 'pi_3QxTest01',
      paidAt: DateTime(2026, 11, 1, 14, 31),
    );

Order _unpaidOrder() => Order(
      id: 8,
      productId: 3,
      buyerId: 2,
      buyerName: 'Hermione',
      quantity: 2,
      totalPrice: 10.0,
      status: 'pending',
      createdAt: DateTime(2026, 11, 1, 14, 30),
      productName: 'Kelapa',
      paymentMethod: 'stripe',
      paymentStatus: 'pending',
      paymentUrl: 'https://checkout.stripe.com/c/pay/cs_test_abc',
    );

void main() {
  testWidgets('receipt shows the amount, reference number and farmer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(order: _paidOrder())));

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('RM 18.00'), findsOneWidget);
    expect(find.text('pi_3QxTest01'), findsOneWidget);
    expect(find.text('Puan Siti'), findsOneWidget);
    expect(find.text('#TAMU-0007'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.textContaining('Simulated payment through Stripe'), findsOneWidget);
  });

  testWidgets('a cancelled paid order shows as refunded', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReceiptScreen(order: _paidOrder(status: 'cancelled'))),
    );

    expect(find.text('Payment refunded'), findsOneWidget);
    expect(find.text('Refunded'), findsOneWidget);
  });

  testWidgets('payment screen shows the amount and the payment buttons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PaymentScreen(order: _unpaidOrder(), openOnStart: false),
    ));

    expect(find.text('RM 10.00'), findsOneWidget);
    expect(find.text('Open payment page'), findsOneWidget);
    expect(find.text("I've paid, check status"), findsOneWidget);
    expect(find.text('Cancel order'), findsOneWidget);
    expect(find.textContaining('No real money'), findsOneWidget);
  });

  testWidgets('an unpaid online order is waiting for payment', (tester) async {
    final order = _unpaidOrder();
    expect(order.awaitingPayment, isTrue);
    expect(order.paymentLabel, 'Online payment · Awaiting payment');
    expect(order.hasReceipt, isFalse);
  });
}
