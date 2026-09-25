import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';

/// FR3 Geolocation - nearby farms with a proximity map.
///
/// The map is drawn with CustomPaint from the farm coordinates, so the
/// app needs no map-tile provider and works offline. Each pin is placed
/// by projecting its latitude/longitude onto the visible bounding box.
class NearbyFarmsScreen extends StatefulWidget {
  const NearbyFarmsScreen({super.key});

  @override
  State<NearbyFarmsScreen> createState() => _NearbyFarmsScreenState();
}

class _NearbyFarmsScreenState extends State<NearbyFarmsScreen> {
  late Future<List<NearbyFarm>> _farmsFuture;
  double _radius = 10;

  static const _radiusOptions = [2.0, 5.0, 10.0, 25.0];

  double get _refLat =>
      ApiService.currentUser?.latitude ?? kTamparuliLat;
  double get _refLng =>
      ApiService.currentUser?.longitude ?? kTamparuliLng;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _farmsFuture = ApiService.fetchNearbyFarms(
      lat: _refLat,
      lng: _refLng,
      radiusKm: _radius,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _farmsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final hasOwnLocation = ApiService.currentUser?.hasLocation ?? false;

    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(
        title: const Text('Nearby Farms'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _buildOriginBar(hasOwnLocation),
                _buildRadiusBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<NearbyFarm>>(
                      future: _farmsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return _buildError(snapshot.error.toString());
                        }
                        final farms = snapshot.data ?? [];

                        return ListView(
                          padding:
                              const EdgeInsets.all(TamuSizes.pagePadding),
                          children: [
                            _buildMap(farms),
                            const SizedBox(height: 16),
                            Text(
                              farms.isEmpty
                                  ? 'No farms within ${_radius.toStringAsFixed(0)} km'
                                  : '${farms.length} farm${farms.length == 1 ? "" : "s"} '
                                      'within ${_radius.toStringAsFixed(0)} km',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: TamuSizes.gap),
                            ...farms.map(_buildFarmCard),
                            if (farms.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'Try increasing the search radius.',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: TamuColors.textSecondary),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOriginBar(bool hasOwnLocation) {
    return Container(
      width: double.infinity,
      color: hasOwnLocation ? TamuColors.lightGreen : const Color(0xFFFFF8E1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(hasOwnLocation ? Icons.my_location : Icons.info_outline,
              size: 18,
              color:
                  hasOwnLocation ? TamuColors.primary : TamuColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasOwnLocation
                  ? 'Measuring from: ${ApiService.currentUser?.address ?? "your saved location"}'
                  : 'No saved location. Measuring from Tamparuli town. '
                      'Set your location in Profile.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Text('Radius',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          for (final r in _radiusOptions)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text('${r.toStringAsFixed(0)} km',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _radius == r
                            ? Colors.white
                            : TamuColors.textPrimary)),
                selected: _radius == r,
                showCheckmark: false,
                selectedColor: TamuColors.primary,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: _radius == r
                        ? TamuColors.primary
                        : TamuColors.border),
                onSelected: (_) {
                  setState(() {
                    _radius = r;
                    _load();
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(List<NearbyFarm> farms) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5EC),
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _MapPainter(
          farms: farms,
          refLat: _refLat,
          refLng: _refLng,
          radiusKm: _radius,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildFarmCard(NearbyFarm f) {
    return Container(
      margin: const EdgeInsets.only(bottom: TamuSizes.gap),
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: TamuColors.lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
                child: Text('🌾', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.farmName ?? f.farmerName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(f.farmerName,
                    style: const TextStyle(
                        fontSize: 13, color: TamuColors.textSecondary)),
                if (f.address != null)
                  Text(f.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: TamuColors.textSecondary)),
                const SizedBox(height: 4),
                Text('${f.listings} listing${f.listings == 1 ? "" : "s"}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: TamuColors.primary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: TamuColors.lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              f.distanceKm == null
                  ? '-'
                  : '${f.distanceKm!.toStringAsFixed(1)} km',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: TamuColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.location_off,
            size: 56, color: TamuColors.textSecondary),
        const SizedBox(height: 12),
        const Text('Cannot load farms',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(msg.replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: TamuColors.danger)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
      ],
    );
  }
}

/// Draws the proximity map: concentric range rings, the buyer at the
/// centre, and a pin for each farm positioned by its real coordinates.
class _MapPainter extends CustomPainter {
  final List<NearbyFarm> farms;
  final double refLat;
  final double refLng;
  final double radiusKm;

  _MapPainter({
    required this.farms,
    required this.refLat,
    required this.refLng,
    required this.radiusKm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // Leave a margin so pins at max radius stay inside the box.
    final maxPixelRadius = math.min(size.width, size.height) / 2 - 26;
    final pxPerKm = maxPixelRadius / radiusKm;

    // --- grid ---
    final grid = Paint()
      ..color = const Color(0xFFD7E4D0)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // --- range rings ---
    final ring = Paint()
      ..color = TamuColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 1; i <= 3; i++) {
      final km = radiusKm * i / 3;
      canvas.drawCircle(centre, km * pxPerKm, ring);
      _label(canvas, '${km.toStringAsFixed(km < 10 ? 1 : 0)} km',
          Offset(centre.dx + km * pxPerKm - 18, centre.dy - 14),
          10, TamuColors.textSecondary);
    }

    // --- centre marker (you) ---
    canvas.drawCircle(centre, 7, Paint()..color = TamuColors.info);
    canvas.drawCircle(
        centre,
        7,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    _label(canvas, 'You', Offset(centre.dx - 10, centre.dy + 10), 11,
        TamuColors.info, bold: true);

    // --- farm pins ---
    // 1 degree of latitude is about 111 km. Longitude shrinks by cos(lat).
    const kmPerDegLat = 111.0;
    final kmPerDegLng = 111.0 * math.cos(refLat * math.pi / 180);

    for (final f in farms) {
      final dxKm = (f.longitude - refLng) * kmPerDegLng;
      final dyKm = (f.latitude - refLat) * kmPerDegLat;

      final pos = Offset(
        centre.dx + dxKm * pxPerKm,
        centre.dy - dyKm * pxPerKm, // north is up
      );

      // Connector line
      canvas.drawLine(
          centre,
          pos,
          Paint()
            ..color = TamuColors.secondary.withValues(alpha: 0.5)
            ..strokeWidth = 1);

      canvas.drawCircle(pos, 8, Paint()..color = TamuColors.primary);
      canvas.drawCircle(
          pos,
          8,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      final name = f.farmName ?? f.farmerName;
      _label(canvas, name, Offset(pos.dx - 24, pos.dy + 11), 10,
          TamuColors.textPrimary, bold: true);
    }
  }

  void _label(Canvas canvas, String text, Offset at, double size, Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.farms != farms || old.radiusKm != radiusKm;
}