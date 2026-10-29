import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../i18n.dart';
import '../map_config.dart';
import '../screens/location_picker_screen.dart' as location_picker;
import '../theme.dart';

/// The point a user pinned, or none. Changes notify the [MapPinField].
class MapPinController extends ChangeNotifier {
  MapPinController({this.latitude, this.longitude});

  /// Change these through [set] and [clear] so the field redraws.
  double? latitude;
  double? longitude;

  bool get hasPin => latitude != null && longitude != null;

  void set(double newLatitude, double newLongitude) {
    latitude = newLatitude;
    longitude = newLongitude;
    notifyListeners();
  }

  void clear() {
    latitude = null;
    longitude = null;
    notifyListeners();
  }
}

/// A location chosen by tapping the real map (no typed coordinates): shows a
/// small preview of the pinned spot with Change / Remove, or a button to
/// pin it.
class MapPinField extends StatelessWidget {
  final MapPinController controller;
  final bool isFarmer;

  /// Shown when nothing is pinned yet.
  final String emptyText;

  const MapPinField({
    super.key,
    required this.controller,
    required this.isFarmer,
    required this.emptyText,
  });

  Future<void> _pick(BuildContext context) async {
    final picked =
        await Navigator.of(context).push<location_picker.LocationPickResult>(
      MaterialPageRoute(
        builder: (_) => location_picker.LocationPickerScreen(
          initialLatitude: controller.latitude,
          initialLongitude: controller.longitude,
          isFarmer: isFarmer,
        ),
      ),
    );
    if (picked != null) controller.set(picked.latitude, picked.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.hasPin) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TamuColors.lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emptyText, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pick(context),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Pin on map'),
                  ),
                ),
              ],
            ),
          );
        }

        final point = LatLng(controller.latitude!, controller.longitude!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 130,
                child: FlutterMap(
                  // A new key moves the preview when the pin changes.
                  key: ValueKey(point),
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                    onTap: (_, _) => _pick(context),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tamuOsmTileUrl,
                      userAgentPackageName: tamuOsmUserAgentPackageName,
                      maxNativeZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 40,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on,
                              size: 40, color: TamuColors.primary),
                        ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: TamuColors.primary),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Pinned on map',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TamuColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(context),
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                    label: const Text('Change'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: controller.clear,
                  style:
                      TextButton.styleFrom(foregroundColor: TamuColors.danger),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
