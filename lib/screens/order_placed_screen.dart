import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../api_service.dart';
import 'orders_screen.dart' as orders;
import 'receipt_screen.dart';

/// FR5 Order placed confirmation (Figma "Confirmation").
/// Pushed by CheckoutScreen with only the marketplace underneath it.
class OrderPlacedScreen extends StatelessWidget {
  final Order order;

  const OrderPlacedScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(15));
    final buttonText =
        GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700);

    return Scaffold(
      backgroundColor: TamuColors.warm,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 60, 22, 35),
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: TamuColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x3D2E7D32),
                            blurRadius: 25,
                            offset: Offset(0, 10)),
                      ],
                    ),
                    child:
                        const Icon(Icons.check, size: 44, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 15),
                Center(child: _demoTag()),
                const SizedBox(height: 15),
                const Text('Order placed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: TamuColors.darkGreen)),
                const SizedBox(height: 8),
                Text(
                  'Your order was sent to ${order.farmerName ?? 'the farmer'}. '
                  "You'll be notified when it is confirmed.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: TamuColors.textSecondary),
                ),
                const SizedBox(height: 22),
                _buildSummaryCard(),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => const orders.OrdersScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: buttonShape,
                    textStyle: buttonText,
                  ),
                  child: const Text('Track this order'),
                ),
                const SizedBox(height: 10),
                if (order.hasReceipt) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ReceiptScreen(order: order)),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: TamuColors.primary),
                      shape: buttonShape,
                      textStyle: buttonText,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View receipt'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: TamuColors.line),
                    shape: buttonShape,
                    textStyle: buttonText,
                  ),
                  child: const Text('Back to marketplace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The order is real, the payment is not, so label the payment honestly.
  Widget _demoTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border.all(color: const Color(0xFFA7B6A8)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text('DEMO PAYMENT · NO MONEY CHARGED',
          style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF526354))),
    );
  }

  Widget _buildSummaryCard() {
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: TamuColors.textSecondary)),
              ),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: value),
              ),
            ],
          ),
        );
    Text strong(String s) => Text(s,
        textAlign: TextAlign.right,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TamuColors.darkGreen));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: TamuColors.line),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A182D1A), blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ORDER',
              style: TextStyle(fontSize: 11, color: TamuColors.textSecondary)),
          const SizedBox(height: 3),
          Text('#TAMU-${order.id.toString().padLeft(4, '0')}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: TamuColors.darkGreen)),
          const Divider(height: 30, color: TamuColors.line),
          row(
            'Status',
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                  color: TamuColors.amberBg,
                  borderRadius: BorderRadius.circular(30)),
              child: const Text('Pending',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: TamuColors.amber)),
            ),
          ),
          row('Crop',
              strong('${order.productName ?? 'Crop'} · '
                  '${formatUnitQuantity(order.quantity, order.unit)}')),
          row('Total', strong('RM ${order.totalPrice.toStringAsFixed(2)}')),
          row('Method', strong(order.fulfilmentLabel)),
          row(order.isDelivery ? 'Deliver to' : 'Pickup at',
              strong(order.handoverPlace)),
          row('Payment', strong(order.paymentLabel)),
        ],
      ),
    );
  }
}
