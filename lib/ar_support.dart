import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// FR4: which kind of AR this phone can do.
///
/// * Floor AR (Google Scene Viewer) needs Google ARCore, which only runs on
///   phones Google has certified. Many budget phones (e.g. Redmi 12) are not.
/// * Other phones show the 3D view (rotate / zoom) without AR.
class ArSupport {
  static const _channel = MethodChannel('tamu/ar');
  static bool? _hasArCore;

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
