import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../api_service.dart';
import '../ar_support.dart';
import '../theme.dart';
import 'marker_card_screen.dart';

/// FR4: marker-based WebAR, for phones without Google ARCore.
///
/// Runs assets/ar/marker_ar.html (A-Frame + AR.js) in an in-app WebView.
/// A tiny server on 127.0.0.1 (inside the app) serves the page, the crop
/// model and the marker pattern: localhost counts as a secure origin, so
/// the camera is allowed, and no large data has to pass through the main
/// thread. The WebView uses hybrid composition: drawing WebGL + camera
/// through Flutter's texture deadlocked the main thread (ANR) on a Redmi 12.
class MarkerArScreen extends StatefulWidget {
  final Product product;

  const MarkerArScreen({super.key, required this.product});

  @override
  State<MarkerArScreen> createState() => _MarkerArScreenState();
}

enum _Stage { preparing, noCamera, failed, running }

class _MarkerArScreenState extends State<MarkerArScreen> {
  _Stage _stage = _Stage.preparing;
  String _error = '';
  bool _cameraOn = false;
  bool _found = false;
  WebViewController? _controller;
  HttpServer? _server;
  Timer? _slowTimer;
  bool _slow = false;

  Product get p => widget.product;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.preparing;
      _slow = false;
    });

    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(() => _stage = _Stage.noCamera);
      return;
    }

    try {
      final pageUrl = await _startLocalServer();
      final controller =
          WebViewController(
              // The page asks for the camera; the app already has permission.
              onPermissionRequest: (request) => request.grant(),
            )
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.black)
            ..addJavaScriptChannel('TamuAR', onMessageReceived: _onPageMessage);
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        // Let the camera video start without a tap.
        await platform.setMediaPlaybackRequiresUserGesture(false);
      }
      await controller.loadRequest(pageUrl);
      if (!mounted) return;
      _slowTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && !_cameraOn) setState(() => _slow = true);
      });
      setState(() {
        _controller = controller;
        _stage = _Stage.running;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Downloads the model, then serves page + model + pattern on
  /// 127.0.0.1 for the WebView. Returns the page address.
  Future<Uri> _startLocalServer() async {
    final url = resolveServerUrl(p.modelUrl);
    if (url == null) throw Exception('This crop has no 3D model.');
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception(
        'Could not download the 3D model (${response.statusCode}).',
      );
    }
    final model = response.bodyBytes;
    final patt = await rootBundle.loadString('assets/ar/tamu_marker.patt');
    // AR.js measures in marker widths; models are in metres.
    final scale = (100 / ArSupport.markerCm).toStringAsFixed(4);
    final safeName = p.name
        .replaceAll(r'\', '')
        .replaceAll("'", '’')
        .replaceAll('<', '')
        .replaceAll('>', '');
    final html = (await rootBundle.loadString('assets/ar/marker_ar.html'))
        .replaceAll('{{SOURCE}}', 'sourceType: webcam')
        .replaceAll('{{SCALE}}', scale)
        .replaceAll('{{NAME}}', safeName);

    await _server?.close(force: true);
    // Port 0 = any free port; only reachable from this phone.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      final res = request.response;
      switch (request.uri.path) {
        case '/ar.html':
          res.headers.contentType = ContentType.html;
          res.write(html);
        case '/model.glb':
          res.headers.contentType = ContentType('model', 'gltf-binary');
          res.add(model);
        case '/marker.patt':
          res.headers.contentType = ContentType.text;
          res.write(patt);
        default:
          res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    });
    return Uri.parse('http://127.0.0.1:${server.port}/ar.html');
  }

  void _onPageMessage(JavaScriptMessage message) {
    if (!mounted) return;
    switch (message.message) {
      case 'camera-on':
        setState(() => _cameraOn = true);
      case 'marker-found':
        setState(() => _found = true);
      case 'camera-error':
        setState(() {
          _stage = _Stage.failed;
          _error = 'The camera could not be started.';
        });
      case 'model-error':
        setState(() {
          _stage = _Stage.failed;
          _error = 'The 3D model could not be shown.';
        });
    }
  }

  void _openCard() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MarkerCardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: TamuColors.darkGreen,
        title: Text('${p.name} · TAMU card AR'),
        actions: [
          IconButton(
            tooltip: 'Show the TAMU card',
            onPressed: _openCard,
            icon: const Icon(Icons.qr_code_2),
          ),
        ],
      ),
      body: switch (_stage) {
        _Stage.preparing => _message(
          icon: null,
          title: 'Getting AR ready...',
          body: 'Loading ${p.name} in 3D.',
        ),
        _Stage.noCamera => _message(
          icon: Icons.no_photography_outlined,
          title: 'Camera permission needed',
          body:
              'TAMU needs the camera to show the crop on the TAMU card. '
              'Nothing is recorded or uploaded.',
          action: (
            'Allow camera',
            () async {
              final status = await Permission.camera.status;
              if (status.isPermanentlyDenied) {
                await openAppSettings();
              } else {
                await _start();
              }
            },
          ),
        ),
        _Stage.failed => _message(
          icon: Icons.error_outline,
          title: 'AR could not start',
          body: _error,
          action: ('Try again', _start),
        ),
        _Stage.running => Stack(
          children: [
            Positioned.fill(child: _webView()),
            if (!_cameraOn)
              Positioned.fill(
                child: _message(
                  icon: null,
                  title: _slow ? 'Still loading...' : 'Starting the camera...',
                  body: _slow
                      ? 'The first time, AR needs an internet connection '
                            'to load. Check your data or Wi-Fi.'
                      : 'Point the camera at the TAMU card.',
                ),
              ),
            if (_cameraOn && !_found)
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: TamuColors.primary,
                    ),
                    title: const Text('No TAMU card?'),
                    subtitle: const Text('Print it or show it on a screen.'),
                    trailing: TextButton(
                      onPressed: _openCard,
                      child: const Text('Show'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }

  /// Hybrid composition on Android: the WebView is drawn by Android itself
  /// instead of through a Flutter texture (which froze the app with WebGL
  /// and camera video).
  Widget _webView() {
    final controller = _controller!;
    if (controller.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  Widget _message({
    required IconData? icon,
    required String title,
    required String body,
    (String, Future<void> Function())? action,
  }) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            const CircularProgressIndicator(color: TamuColors.secondary)
          else
            Icon(icon, size: 52, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.white70,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(onPressed: action.$2, child: Text(action.$1)),
          ],
        ],
      ),
    );
  }
}
