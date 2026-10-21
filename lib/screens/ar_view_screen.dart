import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../theme.dart';
import '../api_service.dart';

/// FR4 - AR Visualization.
///
/// Uses Google's `<model-viewer>` component (via model_viewer_plus) to
/// render a glTF/GLB model. The same widget gives:
///   * interactive 3D inspection (rotate, pinch to zoom) everywhere
///   * true augmented reality on ARCore devices, where the crop is
///     placed at real-world scale on the floor through the camera
class ArViewScreen extends StatefulWidget {
  final Product product;
  const ArViewScreen({super.key, required this.product});

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> {
  bool _autoRotate = true;

  Product get p => widget.product;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.darkGreen,
      appBar: AppBar(
        backgroundColor: TamuColors.darkGreen,
        title: Text('${p.name} in 3D / AR'),
        actions: [
          IconButton(
            tooltip: _autoRotate ? 'Stop rotating' : 'Auto-rotate',
            onPressed: () => setState(() {
              _autoRotate = !_autoRotate;
            }),
            icon: Icon(_autoRotate ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(child: _buildViewer()),
                _buildInfoPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    if (!p.hasArModel) return _buildNoModel();

    return Container(
      margin: const EdgeInsets.all(TamuSizes.pagePadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.secondary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: ModelViewer(
        key: ValueKey('${p.modelUrl}-$_autoRotate'),
        src: p.modelUrl!,
        alt: '3D model of ${p.name}',
        // ar: true enables Scene Viewer on Android / Quick Look on iOS.
        ar: true,
        arModes: const ['scene-viewer', 'webxr', 'quick-look'],
        arPlacement: ArPlacement.floor,
        // Catalogue crops are built at real size, so lock the AR scale to
        // keep them life-size. A farmer's own upload has an unknown scale,
        // so buyers may resize that one.
        arScale: p.hasOwnScan ? ArScale.auto : ArScale.fixed,
        autoRotate: _autoRotate,
        cameraControls: true,
        disableZoom: false,
        backgroundColor: const Color(0xFFF5F5F5),
        loading: Loading.eager,
        // A big labelled button instead of model-viewer's small corner
        // icon. model-viewer only shows it on phones that support AR.
        innerModelViewerHtml: '''
<button slot="ar-button" style="position:absolute;left:50%;bottom:16px;
  transform:translateX(-50%);padding:14px 22px;border:0;border-radius:28px;
  background:#2E7D32;color:#fff;font:600 16px sans-serif;
  box-shadow:0 4px 12px rgba(0,0,0,.25);">
  &#128247; View in my room
</button>''',
      ),
    );
  }

  Widget _buildNoModel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined,
                size: 64, color: Colors.white38),
            const SizedBox(height: 14),
            const Text(
              'No 3D model attached',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'The farmer has not chosen a 3D model for ${p.name} yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(p.farmName ?? p.farmerName,
                        style: const TextStyle(
                            fontSize: 14, color: TamuColors.textSecondary)),
                  ],
                ),
              ),
              Text('RM ${p.pricePerUnit.toStringAsFixed(2)} / ${p.unit}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TamuColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          if (p.hasArModel)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TamuColors.lightGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 20, color: TamuColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Drag to turn, pinch to zoom. Tap "View in my room" '
                      'and point your camera at a table or floor to see the '
                      'crop at its real size. Needs a phone with Google AR '
                      'support; otherwise you still get the 3D view.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
