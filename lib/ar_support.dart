import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';

/// FR4: which kind of AR this phone can do.
///
/// * Floor AR (Google Scene Viewer) needs Google ARCore, which only runs on
///   phones Google has certified. Many budget phones (e.g. Redmi 12) are not.
/// * Marker AR works on any Android phone with a camera: the buyer points
///   it at the printed TAMU card and the crop stands on the card.
class ArSupport {
  static const _channel = MethodChannel('tamu/ar');
  static bool? _hasArCore;

  /// Printed width of the black square on the TAMU card. Must match
  /// MARKER_CM in the backend's make_marker.py.
  static const markerCm = 15.0;

  static String get printableCardUrl =>
      '$kBaseUrl/models/marker/tamu_marker_print.png';

  /// Marker AR runs in an in-app WebView (Android / iOS apps, not web).
  static bool get markerArAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// True when the phone can place models on the floor by itself.
  static Future<bool> hasFloorAr() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true; // Quick Look
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    if (_hasArCore != null) return _hasArCore!;
    try {
      _hasArCore = await _channel.invokeMethod<bool>('hasArCore') ?? false;
    } catch (_) {
      _hasArCore = false;
    }
    return _hasArCore!;
  }
}
