import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';
import '../api_service.dart';
import '../map_config.dart';

/// FR3 Geolocation - nearby farms shown on real OpenStreetMap tiles.
/// Farm pins and the buyer's search radius use latitude/longitude values
/// returned by the FastAPI backend.
class NearbyFarmsScreen extends StatefulWidget {
  final int? focusFarmId;
  final double? focusLatitude;
  final double? focusLongitude;
  final String? focusLabel;

  const NearbyFarmsScreen({
    super.key,
    this.focusFarmId,
    this.focusLatitude,
    this.focusLongitude,
    this.focusLabel,
  });

  @override
  State<NearbyFarmsScreen> createState() => _NearbyFarmsScreenState();
}

class _NearbyFarmsScreenState extends State<NearbyFarmsScreen> {
  late Future<List<NearbyFarm>> _farmsFuture;
  double _radius = 10;
  final MapController _mapController = MapController();
  bool _mapReady = false;

  static const _radiusOptions = [2.0, 5.0, 10.0, 25.0];

  double get _refLat =>
      ApiService.currentUser?.latitude ?? kTamparuliLat;
  double get _refLng =>
      ApiService.currentUser?.longitude ?? kTamparuliLng;

  LatLng get _cameraCenter {
    if (widget.focusLatitude != null && widget.focusLongitude != null) {
      return LatLng(widget.focusLatitude!, widget.focusLongitude!);
    }
    return LatLng(_refLat, _refLng);
  }

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

  double _zoomForRadius(double radius) => switch (radius) {
        <= 2 => 13.5,
        <= 5 => 12.5,
        <= 10 => 11.5,
        _ => 10.3,
      };

  void _selectRadius(double radius) {
    setState(() {
      _radius = radius;
      _load();
    });

    if (_mapReady) {
      _mapController.move(
        _cameraCenter,
        _zoomForRadius(radius),
      );
    }
  }

  List<Marker> _markersFor(List<NearbyFarm> farms) {
    final markers = <Marker>[
      Marker(
        point: LatLng(_refLat, _refLng),
        width: 42,
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            color: TamuColors.info,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 5),
            ],
          ),
          child: const Icon(Icons.my_location, size: 19, color: Colors.white),
        ),
      ),
    ];

    final focusedFarmIsListed = farms.any(
      (farm) => farm.ownerId == widget.focusFarmId,
    );
    for (final farm in farms) {
      final isFocused = farm.ownerId == widget.focusFarmId;
      markers.add(
        Marker(
          point: LatLng(farm.latitude, farm.longitude),
          width: 44,
          height: 48,
          alignment: Alignment.topCenter,
          child: Tooltip(
            message: tr(farm.farmName ?? farm.farmerName),
            child: Icon(
              Icons.location_on,
              size: 42,
              color: isFocused ? TamuColors.warning : TamuColors.primary,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 3)],
            ),
          ),
        ),
      );
    }

    if (widget.focusFarmId != null &&
        !focusedFarmIsListed &&
        widget.focusLatitude != null &&
        widget.focusLongitude != null) {
      markers.add(
        Marker(
          point: LatLng(widget.focusLatitude!, widget.focusLongitude!),
          width: 48,
          height: 52,
          alignment: Alignment.topCenter,
          child: Tooltip(
            message: tr(widget.focusLabel ?? 'Selected public pickup point'),
            child: const Icon(
              Icons.location_on,
              size: 46,
              color: TamuColors.warning,
              shadows: [Shadow(color: Colors.black26, blurRadius: 3)],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  List<CircleMarker> _radiusCircle() => [
        CircleMarker(
          point: LatLng(_refLat, _refLng),
          radius: _radius * 1000,
          useRadiusInMeter: true,
          color: TamuColors.secondary.withValues(alpha: 0.12),
          borderColor: TamuColors.primary,
          borderStrokeWidth: 1.5,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final hasOwnLocation = ApiService.currentUser?.hasLocation ?? false;

    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(
        title: const Text('Nearby Farms'),
        actions: [
          IconButton(
            tooltip: tr('Refresh'),
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
                onSelected: (_) => _selectRadius(r),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(List<NearbyFarm> farms) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5EC),
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _cameraCenter,
          initialZoom: widget.focusFarmId == null ? _zoomForRadius(_radius) : 14,
          minZoom: 8,
          maxZoom: 18,
          onMapReady: () => _mapReady = true,
        ),
        children: [
          TileLayer(
            urlTemplate: tamuOsmTileUrl,
            userAgentPackageName: tamuOsmUserAgentPackageName,
            maxNativeZoom: 19,
          ),
          CircleLayer(circles: _radiusCircle()),
          MarkerLayer(markers: _markersFor(farms)),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
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
