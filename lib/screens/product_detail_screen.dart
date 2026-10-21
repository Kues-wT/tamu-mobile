import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';
import '../api_service.dart';
import '../widgets/crop_photo.dart';
import '../map_config.dart';
import 'ar_view_screen.dart';
import 'checkout_screen.dart';
import 'photo_viewer_screen.dart';
import 'nearby_farms_screen.dart';

/// Product detail. "Review order" opens the FR5 checkout screen.
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  Product get p => widget.product;
  String get _unitPlural => formatUnitQuantity(2, p.unit).split(' ').last;

  double get _total => p.pricePerUnit * _quantity;

  bool get _notYetAvailable {
    final from = p.availableFrom;
    return from != null && DateUtils.dateOnly(DateTime.now()).isBefore(
      DateUtils.dateOnly(from),
    );
  }

  bool get _availabilityEnded {
    final until = p.availableUntil;
    return until != null && DateUtils.dateOnly(DateTime.now()).isAfter(
      DateUtils.dateOnly(until),
    );
  }

  String _availabilityDate(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  String get _availabilitySummary {
    final from = p.availableFrom;
    final until = p.availableUntil;
    if (from != null && until != null) {
      return 'Available ${_availabilityDate(from)} to ${_availabilityDate(until)}';
    }
    if (from != null) return 'Available from ${_availabilityDate(from)}';
    if (until != null) return 'Available until ${_availabilityDate(until)}';
    return '';
  }

  void _changeQty(int delta) {
    final next = _quantity + delta;
    if (next < 1 || next > p.stockQuantity) return;
    setState(() {
      _quantity = next;
    });
  }

  Future<void> _openNearbyFarms() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyFarmsScreen(
          focusFarmId: p.ownerId,
          focusLatitude: p.latitude,
          focusLongitude: p.longitude,
          focusLabel: p.farmName ?? p.farmerName,
        ),
      ),
    );
  }

  /// FR5: the order itself is placed on the Review order screen.
  void _reviewOrder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(product: p, quantity: _quantity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBuyer = ApiService.currentUser?.isBuyer ?? false;

    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(title: Text(p.name)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(TamuSizes.pagePadding),
              children: [
                _buildImageArea(),
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 12),
                _buildArButton(),
                const SizedBox(height: 16),
                _buildPickupLocationCard(),
                const SizedBox(height: 16),
                if (_availabilityEnded)
                  _buildAvailabilityNotice(
                    'This listing ended on ${_availabilityDate(p.availableUntil!)}.',
                  )
                else if (_notYetAvailable)
                  _buildAvailabilityNotice(
                    'Available from ${_availabilityDate(p.availableFrom!)}.',
                  )
                else if (p.isOutOfStock)
                  _buildOutOfStock()
                else if (!isBuyer)
                  _buildBuyerOnlyNote()
                else ...[
                  _buildQuantityPicker(),
                  const SizedBox(height: 16),
                  _buildTotalCard(),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _reviewOrder,
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: Text('Review order · RM ${_total.toStringAsFixed(2)}'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose pickup or delivery on the next screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: TamuColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPhoto() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(photoUrl: p.photoUrl!, title: p.name),
      ),
    );
  }

  Widget _buildImageArea() {
    final hasPhoto = p.photoUrl != null;
    return Container(
      height: hasPhoto ? 240 : 160,
      decoration: BoxDecoration(
        color: TamuColors.lightGreen,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: hasPhoto,
              label: hasPhoto ? 'View full photo' : null,
              child: GestureDetector(
                onTap: hasPhoto ? _openPhoto : null,
                // contain: the whole photo is visible, not a cropped zoom.
                child: CropPhoto(
                  photoUrl: p.photoUrl,
                  category: p.category,
                  height: 240,
                  radius: TamuSizes.cardRadius,
                  emojiSize: 72,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          if (hasPhoto)
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.black54,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _openPhoto,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_out_map, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('View photo',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // FR4: AR badge, only when a 3D model is attached.
          if (p.hasArModel)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TamuColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('3D / AR',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// FR4: opens the 3D / AR viewer.
  Widget _buildArButton() {
    if (!p.hasArModel) {
      return Container(
        padding: const EdgeInsets.all(TamuSizes.cardPadding),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        ),
        child: const Row(
          children: [
            Icon(Icons.view_in_ar_outlined,
                size: 20, color: TamuColors.textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Text('No 3D model available for this crop yet.',
                  style: TextStyle(
                      fontSize: 14, color: TamuColors.textSecondary)),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArViewScreen(product: p)),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: TamuColors.primary,
        side: const BorderSide(color: TamuColors.primary, width: 2),
        backgroundColor: TamuColors.lightGreen,
      ),
      icon: const Icon(Icons.view_in_ar),
      label: const Text('View in 3D / AR'),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: TamuColors.textSecondary),
              const SizedBox(width: 4),
              Text(p.farmerName,
                  style: const TextStyle(
                      fontSize: 16, color: TamuColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 18, color: TamuColors.textSecondary),
              SizedBox(width: 4),
              Text('Tamparuli, Sabah',
                  style: TextStyle(
                      fontSize: 14, color: TamuColors.textSecondary)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RM ${p.pricePerUnit.toStringAsFixed(2)} / ${p.unit}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: TamuColors.primary)),
              _stockBadge(),
            ],
          ),
          if (p.availableFrom != null || p.availableUntil != null) ...[
            const SizedBox(height: 8),
            Text(
              _availabilitySummary,
              style: const TextStyle(
                  fontSize: 13, color: TamuColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// Figma-inspired map card. It deliberately shows an approximate area only:
  /// the exact public pickup point should be confirmed with the farmer.
  Widget _buildPickupLocationCard() {
    final farmName = (p.farmName == null || p.farmName!.trim().isEmpty)
        ? 'Tamparuli pickup area'
        : p.farmName!.trim();
    final distance = p.distanceKm == null
        ? 'Confirm the exact public meeting point with the farmer'
        : 'Approx. ${p.distanceKm!.toStringAsFixed(1)} km away · Confirm the public pickup point';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Pickup location',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: _openNearbyFarms,
                child: const Text('View map'),
              ),
            ],
          ),
          const Text('Public pickup point selected by the seller',
              style: TextStyle(fontSize: 12, color: TamuColors.textSecondary)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              height: 150,
              child: (p.latitude != null && p.longitude != null)
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(p.latitude!, p.longitude!),
                        initialZoom: 14,
                        minZoom: 12,
                        maxZoom: 18,
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
                              point: LatLng(p.latitude!, p.longitude!),
                              width: 42,
                              height: 46,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                size: 42,
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
                    )
                  : Container(
                      color: TamuColors.lightGreen,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(14),
                      child: const Text(
                        'The seller has not added a public pickup location yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: TamuColors.textSecondary),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(farmName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(distance,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: TamuColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _stockBadge() {
    late final Color bg;
    late final Color fg;
    late final String text;

    if (p.isOutOfStock) {
      bg = const Color(0xFFFFEBEE);
      fg = TamuColors.danger;
      text = 'Out of stock';
    } else if (p.isLowStock) {
      bg = const Color(0xFFFFF8E1);
      fg = TamuColors.warning;
      text = 'Only ${formatUnitQuantity(p.stockQuantity, p.unit)} left';
    } else {
      bg = TamuColors.lightGreen;
      fg = TamuColors.primary;
      text = '${formatUnitQuantity(p.stockQuantity, p.unit)} available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style:
              TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildQuantityPicker() {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How many $_unitPlural?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _qtyButton(Icons.remove, () => _changeQty(-1), _quantity > 1),
              Container(
                width: 90,
                alignment: Alignment.center,
                child: Text(formatUnitQuantity(_quantity, p.unit),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              _qtyButton(
                  Icons.add, () => _changeQty(1), _quantity < p.stockQuantity),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Maximum ${formatUnitQuantity(p.stockQuantity, p.unit)}',
                style: const TextStyle(
                    fontSize: 13, color: TamuColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool enabled) {
    return SizedBox(
      width: 56,
      height: 56, // large tap target for older users
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          side: BorderSide(
              color: enabled ? TamuColors.primary : TamuColors.border),
        ),
        child: Icon(icon,
            size: 26,
            color: enabled ? TamuColors.primary : TamuColors.border),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.lightGreen,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.secondary),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 14, color: TamuColors.textSecondary)),
              Text('${formatUnitQuantity(_quantity, p.unit)} × RM ${p.pricePerUnit.toStringAsFixed(2)} / ${p.unit}',
                  style: const TextStyle(fontSize: 14)),
            ],
          ),
          Text('RM ${_total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: TamuColors.primary)),
        ],
      ),
    );
  }

  Widget _buildAvailabilityNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined, color: TamuColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 15, color: TamuColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfStock() {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.danger),
      ),
      child: const Row(
        children: [
          Icon(Icons.remove_shopping_cart_outlined, color: TamuColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text('This crop is currently out of stock.',
                style: TextStyle(fontSize: 16, color: TamuColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerOnlyNote() {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.info),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: TamuColors.info),
          SizedBox(width: 10),
          Expanded(
            child: Text('Only buyer accounts can place orders.',
                style: TextStyle(fontSize: 16, color: TamuColors.info)),
          ),
        ],
      ),
    );
  }
}
