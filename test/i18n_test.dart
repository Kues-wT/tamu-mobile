// Language switch (English / Bahasa Melayu).
//
// Run with:  flutter test test/i18n_test.dart

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter_test/flutter_test.dart';

import 'package:tamu_mobile/i18n.dart';
import 'package:tamu_mobile/screens/login_screen.dart';

void main() {
  tearDown(() => AppLanguage.malay.value = false);

  group('tr()', () {
    test('returns English unchanged while Malay is off', () {
      expect(tr('Sign in'), 'Sign in');
    });

    test('translates exact text, capitals and nullable text', () {
      AppLanguage.malay.value = true;
      expect(tr('Sign in'), 'Log masuk');
      expect(tr('PENDING'), 'MENUNGGU');
      expect(tr<String?>(null), isNull);
      expect(tr('Puan Siti'), 'Puan Siti'); // names stay as they are
    });

    test('fills patterns and translates the parts', () {
      AppLanguage.malay.value = true;
      expect(tr('3 min ago'), '3 minit lalu');
      expect(tr('Order #12 confirmed'), 'Pesanan #12 disahkan');
      expect(tr('2 farms within 10 km'), '2 ladang dalam lingkungan 10 km');
      expect(
        tr('Siti ordered 2 kg of Tuhau (RM 10.00, Pickup).'),
        'Siti memesan 2 kg Tuhau (RM 10.00, Ambil sendiri).',
      );
      expect(tr('Only 3 kg of Tuhau available.'), 'Hanya 3 kg Tuhau tersedia.');
      expect(tr('Pending 3'), 'Menunggu 3');
      expect(tr('Good evening, Puan Siti'), 'Selamat malam, Puan Siti');
      expect(tr('Pickup · Kebun Jumat'), 'Ambil sendiri · Kebun Jumat');
    });

    test('translates validator messages', () {
      AppLanguage.malay.value = true;
      final check = trValidator((v) => v!.isEmpty ? 'Please enter your name' : null)!;
      expect(check(''), 'Sila masukkan nama anda');
      expect(check('Siti'), isNull);
    });
  });

  testWidgets('the BM switch turns the sign-in screen into Malay and back',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Selamat kembali'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(AppLanguage.malay.value, isTrue);
    expect(find.text('Selamat kembali'), findsOneWidget);
    expect(find.text('Log masuk'), findsWidgets);

    // Every visible text is Malay or a name, not leftover English.
    final shown = tester
        .widgetList<m.Text>(find.byType(m.Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(shown, isNot(contains('Sign in')));
    expect(shown, isNot(contains('Create account')));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
