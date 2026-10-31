import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import '../api_service.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "12 Oct 2026, 7:47 PM" in the phone's local time.
String formatReceiptTime(DateTime t) {
  final local = t.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '${local.day} ${tr(_months[local.month - 1])} ${local.year}, '
      '$hour:$minute $ampm';
}

/// FR5 receipt for an order paid with the demo "Online payment".
/// The order is real; the payment is simulated, so the footer says so.
class ReceiptScreen extends StatelessWidget {
  final Order order;

  const ReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final refunded = order.status == 'cancelled';

    return Scaffold(
      backgroundColor: TamuColors.warm,
      appBar: AppBar(
        backgroundColor: TamuColors.warm,
        foregroundColor: TamuColors.darkGreen,
        elevation: 0,
        title: const Text('Payment receipt'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: TamuColors.line),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x1A182D1A),
                          blurRadius: 30,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        refunded ? Icons.undo : Icons.check_circle,
                        size: 54,
                        color:
                            refunded ? TamuColors.amber : TamuColors.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        refunded ? 'Payment refunded' : 'Payment successful',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: TamuColors.darkGreen),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${order.totalPrice.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: TamuColors.darkGreen),
                      ),
                      const Divider(height: 30, color: TamuColors.line),
                      _row('Receipt no.', order.paymentRef ?? '-'),
                      _row('Date and time',
                          order.paidAt == null
                              ? '-'
                              : formatReceiptTime(order.paidAt!)),
                      _row('Paid to', order.farmerName ?? 'Farmer'),
                      _row('Order',
                          '#TAMU-${order.id.toString().padLeft(4, '0')}'),
                      _row(
                          'Item',
                          '${order.productName ?? 'Crop'} · '
                              '${formatUnitQuantity(order.quantity, order.unit)}'),
                      _row('Payment method', order.paymentLabel),
                      _row('Status', refunded ? 'Refunded' : 'Paid'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Demo receipt for testing. No money was charged.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 11, color: TamuColors.textSecondary),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    textStyle: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: TamuColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TamuColors.darkGreen)),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown before placing an "Online payment" order.
/// Returns true when the buyer taps Pay (after a short processing step).
class OnlinePaySheet extends StatefulWidget {
  final double amount;
  final String farmerName;

  const OnlinePaySheet(
      {super.key, required this.amount, required this.farmerName});

  @override
  State<OnlinePaySheet> createState() => _OnlinePaySheetState();
}

class _OnlinePaySheetState extends State<OnlinePaySheet> {
  bool _processing = false;

  Future<void> _pay() async {
    setState(() => _processing = true);
    // Simulated gateway delay; nothing is sent anywhere.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final amount = 'RM ${widget.amount.toStringAsFixed(2)}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline, color: TamuColors.primary),
                SizedBox(width: 8),
                Text('Online payment',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Pay to ${widget.farmerName}',
                style: const TextStyle(
                    fontSize: 13, color: TamuColors.textSecondary)),
            const SizedBox(height: 4),
            Text(amount,
                style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: TamuColors.darkGreen)),
            const SizedBox(height: 6),
            const Text('Mock payment',
                style:
                    TextStyle(fontSize: 11, color: TamuColors.textSecondary)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _processing ? null : _pay,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                textStyle: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: _processing
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text('Processing payment...'),
                      ],
                    )
                  : Text('Pay now · $amount'),
            ),
            TextButton(
              onPressed:
                  _processing ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
