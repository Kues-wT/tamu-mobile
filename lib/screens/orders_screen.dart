import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(
        title: Text(_isFarmer ? 'Incoming Orders' : 'My Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
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

                        return ListView.builder(
                          padding: const EdgeInsets.all(TamuSizes.pagePadding),
                          itemCount: orders.length,
                          itemBuilder: (context, i) =>
                              _buildOrderCard(orders[i]),
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

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final f = _filters[i];
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
