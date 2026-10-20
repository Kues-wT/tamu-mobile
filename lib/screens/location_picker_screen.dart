import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api_service.dart';
import '../map_config.dart';
import '../theme.dart';

class LocationPickResult {
  final double latitude;
  final double longitude;

  const LocationPickResult({required this.latitude, required this.longitude});
}

/// Lets the farmer tap a real map to choose a public selling/pickup point.
/// Also used for a buyer's delivery pin, and read-only ([readOnly]) when a
/// farmer views where to deliver.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final bool isFarmer;
  final bool readOnly;
  // Optional overrides; null keeps the farmer/buyer profile wording.
  final String? title;
  final String? instruction;
  final String? note;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.isFarmer = true,
    this.readOnly = false,
    this.title,
    this.instruction,
    this.note,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  LatLng? _selectedPoint;

  LatLng get _initialCenter {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    return const LatLng(kTamparuliLat, kTamparuliLng);
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }
  }

  void _confirm() {
    final point = _selectedPoint;
    if (point == null) return;
    Navigator.of(context).pop(
      LocationPickResult(latitude: point.latitude, longitude: point.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = _selectedPoint;
    final instruction =
        widget.instruction ??
        (widget.isFarmer
            ? 'Move the map and tap to pin your public selling / pickup point.'
            : 'Move the map and tap to choose your location.');
    final note =
        widget.note ??
        (widget.isFarmer
            ? 'This point is shown to buyers. Do not choose a private home location unless you intend to share it.'
            : null);
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(
        title: Text(
          widget.title ??
              (widget.isFarmer
                  ? 'Choose public pickup point'
                  : 'Choose my location'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: point == null ? 12 : 15,
                  minZoom: 8,
                  maxZoom: 19,
                  onTap: widget.readOnly
                      ? null
                      : (_, latLng) => setState(() => _selectedPoint = latLng),
                ),
                children: [
                  TileLayer(
                    urlTemplate: tamuOsmTileUrl,
                    userAgentPackageName: tamuOsmUserAgentPackageName,
                    maxNativeZoom: 19,
                  ),
                  if (point != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 48,
                          height: 52,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on,
                            size: 46,
                            color: TamuColors.primary,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: TamuColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TamuColors.textSecondary,
                      ),
                    ),
                  ],
                  if (point != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: TamuColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (widget.readOnly)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: point == null ? null : _confirm,
                            child: const Text('Use this point'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
