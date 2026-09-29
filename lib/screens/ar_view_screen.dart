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
        autoRotate: _autoRotate,
        cameraControls: true,
        disableZoom: false,
        backgroundColor: const Color(0xFFF5F5F5),
        loading: Loading.eager,
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
              Text('RM ${p.pricePerKg.toStringAsFixed(2)} /kg',
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
                      'Drag to rotate, pinch to zoom. On an ARCore phone, '
                      'tap the AR button to place the crop on the floor at '
                      'real size.',
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