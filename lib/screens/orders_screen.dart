import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import '../api_service.dart';
import '../widgets/farmer_bottom_nav.dart';
import 'profile_screen.dart' as profile;
import 'requests_screen.dart' as requests;
import 'notifications_screen.dart' as notifications;
import 'login_screen.dart' as login;
import 'location_picker_screen.dart' as location_picker;

/// Orders list.
/// Farmers see orders RECEIVED for their crops, with Accept / Reject.
/// Buyers see orders they PLACED, and can cancel while pending.
/// The backend decides which rows you get - this screen just shows them.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _ordersFuture;
  String _filter = 'all';
  int? _busyOrderId; // which row is currently saving

  static const _buyerFilters = [
    'all',
    'pending',
    'confirmed',
    'completed',
    'cancelled',
  ];
  static const _farmerFilters = [
    'pending',
    'confirmed',
    'completed',
    'cancelled',
  ];

  bool get _isFarmer => ApiService.currentUser?.isFarmer ?? false;

  @override
  void initState() {
    super.initState();
    _filter = _isFarmer ? 'pending' : 'all';
    // After a page reload or hot restart the in-memory token is gone, so
    // skip the request (it would only return 401) and show "Sign in again".
    _ordersFuture = ApiService.isLoggedIn
        ? ApiService.fetchOrders()
        : Future.value(<Order>[]);
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = ApiService.fetchOrders();
    });
    await _ordersFuture;
  }

  Future<void> _setStatus(Order order, String status, String verb) async {
    setState(() {
      _busyOrderId = order.id;
    });
    try {
      await ApiService.updateOrderStatus(orderId: order.id, status: status);
      if (!mounted) return;
      setState(() {
        _busyOrderId = null;
      });
      await _refresh();
      if (!mounted) return;
      _snack('Order #${order.id} $verb', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyOrderId = null;
      });
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  Future<void> _confirmCancel(Order order) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Order #${order.id} for ${formatUnitQuantity(order.quantity, order.unit)} of '
          '${order.productName ?? "this crop"} will be cancelled.'
          '${_isFarmer && order.status == 'confirmed' ? '\n\nThe stock goes back to your listing and the buyer is notified. Only do this if you have agreed it with the buyer or they did not turn up.' : ''}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Cancel order',
              style: TextStyle(fontSize: 16, color: TamuColors.danger),
            ),
          ),
        ],
      ),
    );
    if (yes == true) await _setStatus(order, 'cancelled', 'cancelled');
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(
          msg,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const notifications.NotificationsScreen(),
      ),
    );
    if (mounted) await _refresh();
  }

  void _openDeliveryPin(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => location_picker.LocationPickerScreen(
          initialLatitude: order.deliveryLatitude,
          initialLongitude: order.deliveryLongitude,
          readOnly: true,
          title: 'Delivery location',
          instruction:
              'Deliver ${order.productName ?? 'this order'} '
              'to ${order.buyerName} here.',
          note: order.deliveryAddress,
        ),
      ),
    );
  }

  Future<void> _signInAgain() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const login.LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiService.isLoggedIn || ApiService.currentUser == null) {
      return _buildSessionExpiredScreen();
    }
    return Scaffold(
      backgroundColor: TamuColors.warm,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  if (_isFarmer) _buildFarmerHeader() else _buildBuyerHeader(),
                  _buildFilterBar(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: FutureBuilder<List<Order>>(
                        future: _ordersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return _buildError(snapshot.error.toString());
                          }

                          final all = snapshot.data ?? [];
                          final orders = _filter == 'all'
                              ? all
                              : all.where((o) => o.status == _filter).toList();
                          if (orders.isEmpty) return _buildEmpty();

                          if (_isFarmer) {
                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: orders.length,
                              itemBuilder: (context, i) =>
                                  _buildFarmerOrderCard(orders[i]),
                            );
                          }

                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            children: [
                              ...orders.map(_buildBuyerOrderCard),
                              const SizedBox(height: 4),
                              _buildOrderStagesCard(),
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
      ),
      bottomNavigationBar: _isFarmer
          ? FarmerBottomNav(
              currentIndex: 2,
              onTap: (index) {
                if (index != 2) navigateToFarmerTab(context, index);
              },
            )
          : _buildBuyerBottomNav(),
    );
  }

  Widget _buildSessionExpiredScreen() {
    return Scaffold(
      backgroundColor: TamuColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: TamuColors.textSecondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your session has ended',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please sign in again to view orders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: TamuColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signInAgain,
                  child: const Text('Sign in again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerHeader() {
    return FutureBuilder<List<Order>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        final pending = (snapshot.data ?? [])
            .where((order) => order.status == 'pending')
            .length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incoming orders',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: TamuColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$pending need attention',
                      style: const TextStyle(
                        fontSize: 12,
                        color: TamuColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh orders',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: TamuColors.textPrimary),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: _openNotifications,
                icon: const Icon(
                  Icons.notifications_none,
                  color: TamuColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuyerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 8, 12),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My orders',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TamuColors.darkGreen,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Track the crops you ordered',
                  style: TextStyle(
                    fontSize: 12,
                    color: TamuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: TamuColors.textPrimary),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: const Icon(
              Icons.notifications_none,
              color: TamuColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Figma ".order-card", plus the pickup/delivery and demo payment
  /// chosen at checkout.
  Widget _buildBuyerOrderCard(Order order) {
    const muted = TextStyle(fontSize: 11, color: TamuColors.textSecondary);
    // Buyers may cancel only before the farmer confirms (backend enforces it).
    final canCancel = order.status == 'pending';

    return Opacity(
      opacity: order.status == 'cancelled' ? 0.7 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TamuColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#TAMU-${order.id.toString().padLeft(4, '0')} · '
                        '${_formatDate(order.createdAt)}',
                        style: muted,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${order.productName ?? 'Crop'} · '
                        '${formatUnitQuantity(order.quantity, order.unit)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TamuColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${order.farmerName ?? 'Farmer'} · '
                        'RM ${order.totalPrice.toStringAsFixed(2)}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(order.status),
              ],
            ),
            const Divider(height: 22, color: TamuColors.line),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  order.isDelivery
                      ? Icons.local_shipping_outlined
                      : Icons.place_outlined,
                  size: 18,
                  color: TamuColors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.fulfilmentLabel} · ${order.handoverPlace}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(order.paymentLabel, style: muted),
                    ],
                  ),
                ),
              ],
            ),
            if (order.status == 'confirmed') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TamuColors.lightGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: TamuColors.forestDark,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confirmed. The farmer is preparing your order. '
                        'To change it, contact the farmer.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: TamuColors.forestDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _confirmCancel(order),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: TamuColors.danger,
                  side: const BorderSide(color: TamuColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Cancel order'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Figma ".status-key".
  Widget _buildOrderStagesCard() {
    const arrow = Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right,
        size: 16,
        color: TamuColors.textSecondary,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF0EC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order stages',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: TamuColors.darkGreen,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusBadge('pending'),
              arrow,
              _statusBadge('confirmed'),
              arrow,
              _statusBadge('completed'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Orders may also be marked Cancelled.',
            style: TextStyle(fontSize: 11, color: TamuColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: TamuColors.border)),
        ),
        child: Row(
          children: [
            _buyerNavItem(Icons.storefront_outlined, 'Market', false, () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }),
            _buyerNavItem(Icons.receipt_long_outlined, 'Orders', true, () {}),
            _buyerNavItem(Icons.forum_outlined, 'Requests', false, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const requests.RequestsScreen(),
                ),
              );
            }),
            _buyerNavItem(Icons.person_outline, 'Profile', false, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const profile.ProfileScreen(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buyerNavItem(
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? TamuColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 5),
            Icon(
              icon,
              size: 19,
              color: selected ? TamuColors.primary : TamuColors.textSecondary,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? TamuColors.primary : TamuColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return FutureBuilder<List<Order>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final filters = _isFarmer ? _farmerFilters : _buyerFilters;
        String labelFor(String status) {
          final label = status[0].toUpperCase() + status.substring(1);
          if (_isFarmer && (status == 'pending' || status == 'confirmed')) {
            final count = all.where((order) => order.status == status).length;
            return '$label $count';
          }
          return label;
        }

        return Container(
          color: TamuColors.warm,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, i) {
                final status = filters[i];
                return _buildFilterChip(
                  labelFor(status),
                  _filter == status,
                  () => setState(() => _filter = status),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Figma ".chips" style: dark pill when selected, white outline otherwise.
  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Center(
      child: Material(
        color: selected ? TamuColors.darkGreen : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? TamuColors.darkGreen : TamuColors.line,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : TamuColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Figma ".manage-order" card.
  Widget _buildFarmerOrderCard(Order order) {
    final busy = _busyOrderId == order.id;
    final quantity = formatUnitQuantity(order.quantity, order.unit);
    final unitPrice = order.quantity == 0
        ? 0.0
        : order.totalPrice / order.quantity;

    return Opacity(
      opacity: order.status == 'cancelled' ? 0.7 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: TamuColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER #TAMU-${order.id.toString().padLeft(4, '0')}',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.4,
                          color: TamuColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatFarmerOrderDate(order.createdAt),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: TamuColors.darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(order.status),
              ],
            ),
            // Product row with a bottom divider (".order-product.compact").
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: TamuColors.line)),
              ),
              child: Row(
                children: [
                  // No crop photos yet, so a leaf tile stands in.
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: TamuColors.lightGreen,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.eco_outlined,
                      color: TamuColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName ?? 'Crop order',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$quantity × RM ${unitPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Buyer: ${order.buyerName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'RM ${order.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TamuColors.darkGreen,
                    ),
                  ),
                ],
              ),
            ),
            // Figma ".fulfil-line": pickup/delivery chosen at checkout.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    order.isDelivery
                        ? Icons.local_shipping_outlined
                        : Icons.place_outlined,
                    size: 22,
                    color: TamuColors.darkGreen,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.fulfilmentLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.handoverPlace,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.paymentLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                        if (order.isDelivery && order.hasDeliveryPin)
                          TextButton.icon(
                            onPressed: () => _openDeliveryPin(order),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 40),
                              textStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('View delivery pin'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._buildFarmerActions(order),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFarmerActions(Order order) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    );
    final label = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    if (order.status == 'pending') {
      return [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _setStatus(order, 'confirmed', 'confirmed'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  elevation: 0,
                  backgroundColor: TamuColors.lightGreen,
                  foregroundColor: TamuColors.forestDark,
                  side: const BorderSide(color: TamuColors.paleBorder),
                  shape: shape,
                  textStyle: label,
                ),
                child: const Text('Confirm order'),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 96,
              child: OutlinedButton(
                onPressed: () => _confirmCancel(order),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  // The theme's default side padding is too wide for a
                  // 96px button and made "Cancel" wrap onto two lines.
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: TamuColors.primary,
                  side: const BorderSide(color: TamuColors.line),
                  shape: shape,
                  textStyle: label,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Stock is deducted when you confirm the order.',
          style: TextStyle(fontSize: 11, color: TamuColors.textSecondary),
        ),
      ];
    }
    if (order.status == 'confirmed') {
      return [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _setStatus(order, 'completed', 'completed'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: TamuColors.primary,
                  foregroundColor: Colors.white,
                  shape: shape,
                  textStyle: label,
                ),
                child: const Text('Mark as completed'),
              ),
            ),
            const SizedBox(width: 7),
            // Only the farmer can cancel once confirmed; stock is returned.
            SizedBox(
              width: 96,
              child: OutlinedButton(
                onPressed: () => _confirmCancel(order),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: TamuColors.danger,
                  side: const BorderSide(color: TamuColors.line),
                  shape: shape,
                  textStyle: label,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ];
    }
    if (order.status == 'completed') {
      return [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: TamuColors.lightGreen,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Row(
            children: [
              Icon(Icons.check, size: 18, color: TamuColors.primary),
              SizedBox(width: 8),
              Text(
                'Order completed.',
                style: TextStyle(fontSize: 12, color: TamuColors.primary),
              ),
            ],
          ),
        ),
      ];
    }
    return const [];
  }

  /// Figma badge tones: amber = pending, green = confirmed/completed,
  /// grey = cancelled.
  Widget _statusBadge(String status) {
    final (Color bg, Color fg, String label) = switch (status) {
      'pending' => (TamuColors.amberBg, TamuColors.amber, 'Pending'),
      'confirmed' => (
        TamuColors.lightGreen,
        TamuColors.forestDark,
        'Confirmed',
      ),
      'completed' => (
        TamuColors.lightGreen,
        TamuColors.forestDark,
        'Completed',
      ),
      _ => (TamuColors.greyBadgeBg, TamuColors.greyBadgeText, 'Cancelled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  String _formatFarmerOrderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final orderDay = DateUtils.dateOnly(date);
    final time = TimeOfDay.fromDateTime(date).format(context);
    if (orderDay == today) return 'Today, $time';
    if (orderDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return '${MaterialLocalizations.of(context).formatShortDate(date)}, $time';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
  }

  Widget _buildEmpty() {
    final title = _filter == 'all'
        ? 'No orders placed yet'
        : 'No $_filter orders';
    final body = _isFarmer
        ? 'Orders from buyers will appear here.'
        : 'Browse the marketplace to place your first order.';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(30, 90, 30, 30),
      children: [
        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFE6EAE5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 34,
              color: Color(0xFF6F7B70),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: TamuColors.darkGreen,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: TamuColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    final cleanMessage = msg.replaceFirst('Exception: ', '');
    if (cleanMessage.toLowerCase().contains('not authenticated') ||
        cleanMessage.contains('401')) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 55),
          const Icon(
            Icons.lock_outline,
            size: 48,
            color: TamuColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your session has ended',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in again to view your orders.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: TamuColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _signInAgain,
            child: const Text('Sign in again'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.wifi_off, size: 56, color: TamuColors.textSecondary),
        const SizedBox(height: 12),
        const Text(
          'Cannot load orders',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          msg.replaceFirst('Exception: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: TamuColors.danger),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
      ],
    );
  }
}
