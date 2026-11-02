// Small pieces of app logic, tested on their own.
//
// Run with:  flutter test test/logic_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:tamu_mobile/api_service.dart';
import 'package:tamu_mobile/screens/receipt_screen.dart';
import 'package:tamu_mobile/screens/requests_screen.dart';

Map<String, dynamic> _orderJson({
  String payment = 'pay_on_handover',
  String fulfilment = 'pickup',
  String? ref,
  String? paidAt,
}) =>
    {
      'id': 7,
      'product_id': 3,
      'buyer_id': 2,
      'buyer_name': 'Hermione',
      'quantity': 4,
      'unit': 'kg',
      'total_price': 18.0,
      'status': 'pending',
      'created_at': '2026-11-01T06:30:00',
      'fulfilment_method': fulfilment,
      'payment_method': payment,
      'payment_ref': ref,
      'paid_at': paidAt,
    };

void main() {
  group('sameCrop (offer listings must match the requested crop)', () {
    test('same crop name matches, ignoring capitals', () {
      expect(sameCrop('Kelapa', 'kelapa'), isTrue);
    });

    test('a shorter name inside a longer one matches', () {
      expect(sameCrop('Bayam', 'Sayur Bayam'), isTrue);
      expect(sameCrop('Kelapa Muda', 'Kelapa'), isTrue);
    });

    test('different crops do not match', () {
      expect(sameCrop('Mangga', 'Kelapa'), isFalse);
      expect(sameCrop('Pandan', 'Padi'), isFalse);
    });

    test('empty names never match', () {
      expect(sameCrop('', 'Kelapa'), isFalse);
    });
  });

  group('formatUnitQuantity', () {
    test('one item keeps the single unit', () {
      expect(formatUnitQuantity(1, 'bunch'), '1 bunch');
    });

    test('more than one uses the plural, except kg', () {
      expect(formatUnitQuantity(3, 'bunch'), '3 bunches');
      expect(formatUnitQuantity(5, 'kg'), '5 kg');
    });
  });

  group('Order payment labels (FR5)', () {
    test('pay on pickup and pay on delivery', () {
      expect(Order.fromJson(_orderJson()).paymentLabel, 'Pay on pickup');
      expect(
        Order.fromJson(_orderJson(fulfilment: 'delivery')).paymentLabel,
        'Pay on delivery',
      );
    });

    test('online payment with a receipt shows as paid', () {
      final order = Order.fromJson(_orderJson(
        payment: 'mock_online',
        ref: 'PAY-261101-A1B2C3',
        paidAt: '2026-11-01T06:31:00',
      ));
      expect(order.hasReceipt, isTrue);
      expect(order.paymentLabel, 'Online payment · Paid');
    });

    test('pay on pickup has no receipt', () {
      expect(Order.fromJson(_orderJson()).hasReceipt, isFalse);
    });
  });

  group('RequestOffer (FR6 bidding)', () {
    test('reads a partial offer from the server', () {
      final offer = RequestOffer.fromJson({
        'id': 1,
        'request_id': 9,
        'farmer_id': 4,
        'farmer_name': 'Puan Siti',
        'product_id': 12,
        'product_name': 'Kelapa',
        'from_home': true,
        'quantity_kg': 10,
        'price_per_kg': 5.0,
        'total_price': 50.0,
        'status': 'open',
        'created_at': '2026-11-01T06:30:00',
      });
      expect(offer.quantityKg, 10);
      expect(offer.fromHome, isTrue);
      expect(offer.totalPrice, 50.0);
      expect(offer.isOpen, isTrue);
    });
  });

  group('formatReceiptTime', () {
    test('shows day, month, year and 12-hour time', () {
      final t = DateTime(2026, 10, 12, 19, 47);
      expect(formatReceiptTime(t), '12 Oct 2026, 7:47 PM');
    });

    test('midnight shows as 12 AM', () {
      expect(formatReceiptTime(DateTime(2026, 1, 5, 0, 5)), '5 Jan 2026, 12:05 AM');
    });
  });
}
