import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'profile_screen.dart' as profile;
import 'requests_screen.dart' as requests;
import 'notifications_screen.dart' as notifications;

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

  static const _filters = ['all', 'pending', 'confirmed', 'completed', 'cancelled'];

  bool get _isFarmer => ApiService.currentUser?.isFarmer ?? false;

  @override
  void initState() {
    super.initState();
    _ordersFuture = ApiService.fetchOrders();
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
          'Order #${order.id} for ${order.quantityKg} kg of '
          '${order.productName ?? "this crop"} will be cancelled.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel order',
                style: TextStyle(fontSize: 16, color: TamuColors.danger)),
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
        content: Text(msg,
            style: const TextStyle(fontSize: 16, color: Colors.white)),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const notifications.NotificationsScreen()),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: _isFarmer
          ? AppBar(
              title: const Text('Incoming Orders'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      body: SafeArea(
        bottom: _isFarmer,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                if (!_isFarmer) _buildBuyerHeader(),
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
                              child: CircularProgressIndicator());
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
                            padding: const EdgeInsets.all(TamuSizes.pagePadding),
                            itemCount: orders.length,
                            itemBuilder: (context, i) =>
                                _buildOrderCard(orders[i]),
                          );
                        }

                        return ListView(
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
      bottomNavigationBar: _isFarmer ? null : _buildBuyerBottomNav(),
    );
  }

  Widget _buildBuyerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My orders',
                    style: TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('Sample order history',
                    style: TextStyle(
                        fontSize: 12, color: TamuColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none,
                color: TamuColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#TAMU-${order.id.toString().padLeft(4, '0')}  ·  ${_formatDate(order.createdAt)}',
                  style: const TextStyle(
                      fontSize: 10, color: TamuColors.textSecondary),
                ),
              ),
              _statusBadge(order.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.productName ?? 'Crop'} · ${order.quantityKg} kg',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '${order.farmerName ?? 'Farmer'} · RM ${order.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 11, color: TamuColors.textSecondary),
          ),
          if (order.status == 'completed') ...[
            const SizedBox(height: 6),
            const Text('Rate this order',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TamuColors.primary)),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderStagesCard() {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1ED),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order stages',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Row(
            children: [
              Text('Pending', style: TextStyle(fontSize: 10, color: TamuColors.warning)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right, size: 14, color: TamuColors.textSecondary),
              ),
              Text('Confirmed', style: TextStyle(fontSize: 10, color: TamuColors.primary)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right, size: 14, color: TamuColors.textSecondary),
              ),
              Text('Completed', style: TextStyle(fontSize: 10, color: TamuColors.primary)),
            ],
          ),
          SizedBox(height: 5),
          Text('Orders may also be marked Cancelled.',
              style: TextStyle(fontSize: 9, color: TamuColors.textSecondary)),
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
                MaterialPageRoute(builder: (_) => const requests.RequestsScreen()),
              );
            }),
            _buyerNavItem(Icons.person_outline, 'Profile', false, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const profile.ProfileScreen()),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buyerNavItem(
      IconData icon, String label, bool selected, VoidCallback onTap) {
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
            Icon(icon, size: 19,
                color: selected ? TamuColors.primary : TamuColors.textSecondary),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? TamuColors.primary : TamuColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = _isFarmer
        ? _filters
        : const ['all', 'pending', 'completed'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final f = filters[i];
            final selected = _filter == f;
            return ChoiceChip(
              label: Text(
                f[0].toUpperCase() + f.substring(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : TamuColors.textPrimary,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: TamuColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                  color: selected ? TamuColors.primary : TamuColors.border),
              onSelected: (_) => setState(() {
                _filter = f;
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order o) {
    final busy = _busyOrderId == o.id;

    return Container(
      margin: const EdgeInsets.only(bottom: TamuSizes.gap),
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Order #${o.id}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              _statusBadge(o.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(o.productName ?? 'Unknown crop',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            _isFarmer
                ? 'Buyer: ${o.buyerName}'
                : 'Farmer: ${o.farmerName ?? "-"}',
            style: const TextStyle(fontSize: 14, color: TamuColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(_formatDate(o.createdAt),
              style: const TextStyle(
                  fontSize: 13, color: TamuColors.textSecondary)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${o.quantityKg} kg',
                  style: const TextStyle(fontSize: 16)),
              Text('RM ${o.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: TamuColors.primary)),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ] else
            ..._buildActions(o),
        ],
      ),
    );
  }

  List<Widget> _buildActions(Order o) {
    final widgets = <Widget>[];

    if (_isFarmer) {
      if (o.status == 'pending') {
        widgets.addAll([
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _setStatus(o, 'confirmed', 'accepted'),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: TamuSizes.gap),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _setStatus(o, 'cancelled', 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TamuColors.danger,
                    side: const BorderSide(color: TamuColors.danger),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Accepting will deduct the stock automatically.',
              style: TextStyle(fontSize: 12, color: TamuColors.textSecondary)),
        ]);
      } else if (o.status == 'confirmed') {
        widgets.addAll([
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _setStatus(o, 'completed', 'completed'),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mark as Completed'),
          ),
        ]);
      }
    } else {
      // Buyer can cancel while it is still pending or confirmed.
      if (o.status == 'pending' || o.status == 'confirmed') {
        widgets.addAll([
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _confirmCancel(o),
            style: OutlinedButton.styleFrom(
              foregroundColor: TamuColors.danger,
              side: const BorderSide(color: TamuColors.danger),
            ),
            child: const Text('Cancel Order'),
          ),
        ]);
      }
    }

    return widgets;
  }

  Widget _statusBadge(String status) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (status) {
      case 'pending':
        bg = const Color(0xFFFFF8E1);
        fg = TamuColors.warning;
        label = 'Pending';
      case 'confirmed':
        bg = const Color(0xFFE3F2FD);
        fg = TamuColors.info;
        label = 'Confirmed';
      case 'completed':
        bg = TamuColors.lightGreen;
        fg = TamuColors.primary;
        label = 'Completed';
      default:
        bg = const Color(0xFFFFEBEE);
        fg = TamuColors.danger;
        label = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Center(child: Text('📦', style: TextStyle(fontSize: 48))),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _filter == 'all'
                ? (_isFarmer ? 'No orders received yet' : 'No orders placed yet')
                : 'No $_filter orders',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _isFarmer
                ? 'Orders from buyers will appear here.'
                : 'Browse the marketplace to place your first order.',
            style: const TextStyle(fontSize: 14, color: TamuColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.wifi_off, size: 56, color: TamuColors.textSecondary),
        const SizedBox(height: 12),
        const Text('Cannot load orders',
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
