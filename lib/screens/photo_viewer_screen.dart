import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import '../api_service.dart';

/// FR2: full-screen crop photo. Pinch or double-tap to zoom, drag to pan.
class PhotoViewerScreen extends StatefulWidget {
  final String photoUrl;
  final String title;

  const PhotoViewerScreen({
    super.key,
    required this.photoUrl,
    required this.title,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _controller = TransformationController();
  Offset _tapPoint = Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Double-tap toggles between fit-to-screen and 2.5x zoom centred on
  /// the point that was tapped.
  void _toggleZoom() {
    const s = 2.5;
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    _controller.value = zoomed
        ? Matrix4.identity()
        : (Matrix4.translationValues(
              -_tapPoint.dx * (s - 1), -_tapPoint.dy * (s - 1), 0)
          ..multiply(Matrix4.diagonal3Values(s, s, 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (d) => _tapPoint = d.localPosition,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    resolveServerUrl(widget.photoUrl)!,
                    fit: BoxFit.contain,
                    semanticLabel: tr('Photo of ${widget.title}'),
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const CircularProgressIndicator(
                                color: Colors.white),
                    errorBuilder: (_, _, _) => const Text(
                      'Could not load this photo.',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Text(
              'Pinch or double-tap to zoom',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
