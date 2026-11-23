import 'dart:async';

import 'package:flutter/widgets.dart';

/// FR8: keeps the red badge counts current while the app is open.
///
/// Calls [onTick] every [interval] while the app is in the foreground, and
/// once straight away when the user comes back to the app. Nothing runs
/// while the app is in the background, so no data or battery is used then.
class BadgeTicker with WidgetsBindingObserver {
  BadgeTicker(this.onTick, {this.interval = const Duration(seconds: 30)});

  final VoidCallback onTick;
  final Duration interval;
  Timer? _timer;
  bool _foreground = true;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) {
      if (_foreground) onTick();
    });
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && !wasForeground) onTick();
  }
}
