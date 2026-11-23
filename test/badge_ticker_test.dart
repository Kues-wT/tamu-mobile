// Live badge refresh (FR8).
//
// Run with:  flutter test test/badge_ticker_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamu_mobile/widgets/badge_ticker.dart';

void main() {
  testWidgets('refreshes every 30 seconds while the app is open',
      (tester) async {
    var ticks = 0;
    await tester.pumpWidget(const SizedBox());
    final ticker = BadgeTicker(() => ticks++)..start();

    await tester.pump(const Duration(seconds: 29));
    expect(ticks, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(ticks, 2);

    ticker.dispose();
  });

  testWidgets('does nothing in the background, refreshes on return',
      (tester) async {
    var ticks = 0;
    await tester.pumpWidget(const SizedBox());
    final ticker = BadgeTicker(() => ticks++)..start();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 90));
    expect(ticks, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(ticks, 1); // straight away, not after another 30 s

    ticker.dispose();
  });

  testWidgets('stops after dispose', (tester) async {
    var ticks = 0;
    await tester.pumpWidget(const SizedBox());
    BadgeTicker(() => ticks++)
      ..start()
      ..dispose();
    await tester.pump(const Duration(minutes: 2));
    expect(ticks, 0);
  });
}
