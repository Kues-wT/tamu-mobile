import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../api_service.dart';
import 'order_placed_screen.dart';

/// FR9 online payment through Stripe Checkout in test mode (simulated).
///
/// Opens the Stripe payment page in the browser. When the buyer comes back
/// to the app, it asks the server whether it is paid; once it is, the
/// order is placed and the farmer is told.
class PaymentScreen extends StatefulWidget {
  final Order order;

  /// Tests pass false so no browser is opened.
  final bool openOnStart;

  const PaymentScreen({super.key, required this.order, this.openOnStart = true});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  late Order _order = widget.order;
  bool _checking = false;
  bool _opened = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.openOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPage());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the browser: see whether the payment went through.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _opened) _check();
  }

  Future<void> _openPage() async {
    final url = _order.paymentUrl;
    if (url == null) return;
    bool ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _opened = ok;
      _message = ok ? null : 'Could not open the payment page.';
    });
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final order = await ApiService.checkPayment(_order.id);
      if (!mounted) return;
      if (order.paymentStatus == 'paid') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => OrderPlacedScreen(order: order)),
          (route) => route.isFirst,
        );
        return;
      }
      setState(() {
        _order = order;
        _checking = false;
        _message = order.status == 'cancelled'
            ? 'This order was cancelled because it was not paid in time.'
            : 'Payment not received yet. Finish paying on the payment '
                'page, then check again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _cancel() async {
    try {
      await ApiService.updateOrderStatus(orderId: _order.id, status: 'cancelled');
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = _order.status == 'cancelled';
    final button = GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15));

    return Scaffold(
      backgroundColor: TamuColors.warm,
      appBar: AppBar(
        backgroundColor: TamuColors.warm,
        foregroundColor: TamuColors.darkGreen,
        elevation: 0,
        title: const Text('Online payment'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
              children: [
                const Icon(Icons.credit_card,
                    size: 52, color: TamuColors.primary),
                const SizedBox(height: 10),
                Text(
                  'RM ${_order.totalPrice.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: TamuColors.darkGreen),
                ),
                Text(
                  'Order #TAMU-${_order.id.toString().padLeft(4, '0')} · '
                  '${_order.productName ?? 'Crop'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: TamuColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pay by card on the secure Stripe page. '
                  'Come back to this app when you are done.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Simulated payment (Stripe test mode): use the test card '
                  '4242 4242 4242 4242, any future date and any CVC. '
                  'No real money is charged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: TamuColors.textSecondary),
                ),
                const SizedBox(height: 22),
                if (!cancelled) ...[
                  ElevatedButton.icon(
                    onPressed: _checking ? null : _openPage,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open payment page'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: shape,
                      textStyle: button,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: const Text("I've paid, check status"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: shape,
                      textStyle: button,
                    ),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: TamuColors.amber),
                  ),
                ],
                const SizedBox(height: 18),
                if (!cancelled)
                  TextButton(
                    onPressed: _checking ? null : _cancel,
                    child: const Text('Cancel order'),
                  )
                else
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('Back to marketplace'),
                  ),
                const Text(
                  'Unpaid online orders are cancelled after 30 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: TamuColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
