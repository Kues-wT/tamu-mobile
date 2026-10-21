import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Marketplace oversight: every order on the platform (read-only; the
/// farmer and buyer still confirm, complete or cancel their own orders).
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _search = TextEditingController();
  String? _status;
  List<AdminOrder> _items = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await AdminApi.orders(
        search: _search.text.trim(),
        status: _status,
      );
      if (mounted) {
        setState(() {
          _items = list;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _reload() {
    setState(() => _loading = true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Orders',
      subtitle: 'All orders between buyers and farmers',
      onRefresh: _load,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SearchBox(
              hint: 'Search order no., buyer, crop or farm',
              controller: _search,
              onSubmitted: (_) => _reload(),
            ),
            FilterChips(
              options: const {
                null: 'All',
                'pending': 'Pending',
                'confirmed': 'Confirmed',
                'completed': 'Completed',
                'cancelled': 'Cancelled',
              },
              selected: _status,
              onChanged: (v) {
                _status = v;
                _reload();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminPanel(
          child: LoadState(
            loading: _loading,
            error: _error,
            empty: _items.isEmpty,
            emptyText: 'No orders match.',
            onRetry: _reload,
            child: AdminTable(
              columns: const [
                'Order',
                'Crop',
                'Buyer',
                'Farm',
                'Total',
                'Handover',
                'Status',
              ],
              widths: const [1.2, 2, 1.6, 1.8, 1.2, 1.3, 1.2],
              rows: [
                for (final o in _items)
                  [
                    CellText('#${o.id}', sub: shortDate(o.createdAt)),
                    CellText(
                      o.productName ?? 'Removed listing',
                      sub: formatUnitQuantity(o.quantity, o.unit),
                    ),
                    CellText(o.buyerName),
                    CellText(
                      o.farmName ?? o.farmerName ?? '-',
                      sub: o.farmName == null ? null : o.farmerName,
                    ),
                    Text(
                      money(o.totalPrice),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CellText(
                      o.fulfilmentMethod == 'delivery' ? 'Delivery' : 'Pickup',
                      sub: o.paymentMethod == 'mock_online'
                          ? 'Online (demo)'
                          : 'Pay on handover',
                    ),
                    StatusPill.forStatus(o.status),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
