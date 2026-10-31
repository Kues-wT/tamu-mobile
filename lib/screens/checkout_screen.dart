import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import '../api_service.dart';
import '../widgets/crop_photo.dart';
import 'location_picker_screen.dart';
import 'order_placed_screen.dart';
import 'receipt_screen.dart';

/// FR5 Review order / checkout (Figma "Checkout").
/// The buyer picks pickup or delivery and a DEMO payment option.
/// No real payment is processed and no card or bank details are asked for.
class CheckoutScreen extends StatefulWidget {
  final Product product;
  final int quantity;

  const CheckoutScreen({
    super.key,
    required this.product,
    required this.quantity,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _fulfilment = 'pickup';
  String _payment = 'pay_on_handover';
  bool _placing = false;
  late final TextEditingController _addressCtrl;
  LocationPickResult? _pin; // optional delivery map pin

  Product get p => widget.product;
  double get _total => p.pricePerUnit * widget.quantity;

  @override
  void initState() {
    super.initState();
    // Prefill with the buyer's saved delivery address, if any.
    _addressCtrl = TextEditingController(
      text: ApiService.currentUser?.address ?? '',
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryPin() async {
    final user = ApiService.currentUser;
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          // Start from the last pin, else the buyer's saved location.
          initialLatitude: _pin?.latitude ?? user?.latitude,
          initialLongitude: _pin?.longitude ?? user?.longitude,
          isFarmer: false,
          title: 'Pin delivery location',
          instruction: 'Move the map and tap where the farmer should deliver.',
          note: 'Only the farmer of this order will see this pin.',
        ),
      ),
    );
    if (result != null && mounted) setState(() => _pin = result);
  }

  Future<void> _placeOrder() async {
    final isDelivery = _fulfilment == 'delivery';
    final address = _addressCtrl.text.trim();
    if (isDelivery && _pin == null && address.length < 5) {
      _snack(
        'For delivery, pin your location on the map or enter an '
        'address (at least 5 characters).',
      );
      return;
    }

    if (_payment == 'mock_online') {
      final paid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) =>
            OnlinePaySheet(amount: _total, farmerName: p.farmerName),
      );
      if (paid != true || !mounted) return;
    }

    setState(() => _placing = true);
    try {
      final order = await ApiService.createOrder(
        productId: p.id,
        quantity: widget.quantity,
        fulfilmentMethod: _fulfilment,
        deliveryAddress: isDelivery && address.isNotEmpty ? address : null,
        deliveryLatitude: isDelivery ? _pin?.latitude : null,
        deliveryLongitude: isDelivery ? _pin?.longitude : null,
        paymentMethod: _payment,
      );
      if (!mounted) return;
      // Clear Product Detail + Checkout so "back" from the confirmation
      // returns to the marketplace, not to a stale checkout.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderPlacedScreen(order: order)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: TamuColors.danger,
        content: Text(
          msg,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickupPlace = p.farmName ?? p.farmerName;

    return Scaffold(
      backgroundColor: TamuColors.warm,
      appBar: AppBar(
        backgroundColor: TamuColors.warm,
        surfaceTintColor: Colors.transparent,
        // The theme's app bar icons are white (for green bars); this bar
        // is light, so the back arrow must be dark to be visible.
        foregroundColor: TamuColors.darkGreen,
        iconTheme: const IconThemeData(color: TamuColors.darkGreen),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review order',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: TamuColors.darkGreen,
              ),
            ),
            Text(
              '1 item · Demo checkout',
              style: TextStyle(fontSize: 12, color: TamuColors.textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                _buildDemoAlert(),
                const SizedBox(height: 15),
                _buildProductRow(),
                _sectionTitle('How will you receive it?'),
                _choice(
                  selected: _fulfilment == 'pickup',
                  icon: Icons.place_outlined,
                  title: 'Pickup',
                  detail: 'Public pickup point · $pickupPlace',
                  onTap: () => setState(() => _fulfilment = 'pickup'),
                ),
                _choice(
                  selected: _fulfilment == 'delivery',
                  icon: Icons.home_outlined,
                  title: 'Delivery',
                  detail: 'Farmer delivers to an address you enter',
                  onTap: () => setState(() => _fulfilment = 'delivery'),
                ),
                if (_fulfilment == 'delivery') ...[
                  const SizedBox(height: 4),
                  _buildPinCard(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    maxLength: 200,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: tr(_pin == null
                          ? 'Delivery address'
                          : 'Address or landmark (optional)'),
                      hintText: tr('e.g. Kg. Rungus, near the surau'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                  _inlineNote(
                    'Pin your location, type an address, or both. Only this '
                    'farmer sees them. Any delivery charge is agreed with the '
                    'farmer; this demo adds no fee.',
                  ),
                ],
                _sectionTitle('Demo payment method'),
                _choice(
                  selected: _payment == 'pay_on_handover',
                  icon: Icons.payments_outlined,
                  title: _fulfilment == 'delivery'
                      ? 'Pay on delivery'
                      : 'Pay on pickup',
                  detail: 'Pay the farmer in person at handover',
                  onTap: () => setState(() => _payment = 'pay_on_handover'),
                ),
                _choice(
                  selected: _payment == 'mock_online',
                  icon: Icons.lock_outline,
                  title: 'Online payment',
                  detail: 'Simulation · no banking details required',
                  onTap: () => setState(() => _payment = 'mock_online'),
                ),
                const SizedBox(height: 14),
                _buildTotals(),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _placing ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _placing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_payment == 'mock_online'
                          ? 'Continue to payment'
                          : 'Place order'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The farmer will review and confirm your order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: TamuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Figma ".demo-alert": amber banner, always visible.
  Widget _buildDemoAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TamuColors.amberBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: Color(0xFF744506)),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF744506),
                ),
                children: [
                  TextSpan(
                    text: 'Demonstration only\n',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'No real payment or money will be processed.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: TamuColors.line),
      ),
      child: Row(
        children: [
          CropPhoto(
            photoUrl: p.photoUrl,
            category: p.category,
            width: 52,
            height: 52,
            emojiSize: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatUnitQuantity(widget.quantity, p.unit)} × '
                  'RM ${p.pricePerUnit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TamuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'RM ${_total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: TamuColors.darkGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: TamuColors.darkGreen,
        ),
      ),
    );
  }

  /// Figma ".choice": radio-style card, thick green border when selected.
  Widget _choice({
    required bool selected,
    required IconData icon,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: selected ? const Color(0xFFFBFFFB) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: selected ? TamuColors.primary : TamuColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.all(9),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: TamuColors.lightGreen,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: TamuColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: TamuColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? TamuColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? TamuColors.primary
                          : const Color(0xFFBBC4BA),
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Delivery map pin: opens the OSM picker; shows the pin once chosen.
  Widget _buildPinCard() {
    final pin = _pin;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: pin == null ? TamuColors.line : TamuColors.paleBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _pickDeliveryPin,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TamuColors.lightGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  pin == null
                      ? Icons.add_location_alt_outlined
                      : Icons.location_on,
                  color: TamuColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin == null
                          ? 'Pin my location on the map'
                          : 'Location pinned',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pin == null
                          ? 'Helps the farmer find you'
                          : '${pin.latitude.toStringAsFixed(5)}, '
                                '${pin.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: TamuColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (pin != null)
                IconButton(
                  tooltip: tr('Remove pin'),
                  onPressed: () => setState(() => _pin = null),
                  icon: const Icon(
                    Icons.close,
                    color: TamuColors.textSecondary,
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: TamuColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inlineNote(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF0EC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.45,
          color: TamuColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTotals() {
    Widget row(String label, String value, {bool total = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: total ? 17 : 13,
              fontWeight: total ? FontWeight.w700 : FontWeight.w400,
              color: total ? TamuColors.darkGreen : TamuColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: total ? 17 : 13,
              fontWeight: FontWeight.w700,
              color: TamuColors.darkGreen,
            ),
          ),
        ],
      ),
    );

    final amount = 'RM ${_total.toStringAsFixed(2)}';
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TamuColors.line)),
      ),
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          row('Items', amount),
          const Divider(height: 12, color: TamuColors.line),
          row('Total', amount, total: true),
        ],
      ),
    );
  }
}
