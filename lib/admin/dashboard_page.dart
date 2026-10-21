import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme.dart';
import 'admin_api.dart';
import 'admin_shell.dart';
import 'admin_widgets.dart';

/// Figure 4.28 - Admin Dashboard.
class DashboardPage extends StatefulWidget {
  final ValueChanged<AdminSection> onOpen;
  const DashboardPage({super.key, required this.onOpen});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AdminOverview? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AdminApi.overview();
      if (mounted) {
        setState(() {
          _data = d;
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

  @override
  Widget build(BuildContext context) {
    final name = ApiService.currentUser?.fullName.split(' ').first ?? 'Admin';
    final d = _data;
    return AdminPage(
      title: 'Dashboard',
      subtitle: "Welcome back, $name. Here's an overview of TAMU today.",
      onRefresh: _load,
      children: [
        LoadState(
          loading: _loading,
          error: _error,
          empty: false,
          emptyText: '',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
          child: d == null ? const SizedBox() : _body(d),
        ),
      ],
    );
  }

  Widget _body(AdminOverview d) {
    final activity = AdminPanel(
      title: 'Recent Activity',
      child: d.recentActivity.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nothing yet.',
                style: TextStyle(color: TamuColors.textSecondary),
              ),
            )
          : Column(
              children: [
                for (final a in d.recentActivity)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: TamuColors.line),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          a.kind == 'user'
                              ? Icons.person_add_alt_1_outlined
                              : Icons.shopping_basket_outlined,
                          size: 20,
                          color: TamuColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            a.text,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          timeAgo(a.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    final links = AdminPanel(
      title: 'Quick Links',
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _link('Manage Users', AdminSection.users),
          _link('Review Products', AdminSection.products),
          _link('View Orders', AdminSection.orders),
          _link('Open Reports', AdminSection.reports),
          _link('Send Announcement', AdminSection.announcements),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TamuColors.lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${d.farmers} farmers and ${d.buyers} buyers registered'
              '${d.suspendedUsers > 0 ? ', ${d.suspendedUsers} suspended' : ''}.'
              '${d.pendingOrders > 0 ? ' ${d.pendingOrders} orders waiting for farmers.' : ''}',
              style: const TextStyle(fontSize: 13, color: TamuColors.primary),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatGrid(
          cards: [
            StatCard(
              label: 'Total Users',
              value: '${d.totalUsers}',
              icon: Icons.people_outline,
              note: '${d.farmers} farmers · ${d.buyers} buyers',
            ),
            StatCard(
              label: 'Active Listings',
              value: '${d.activeListings}',
              icon: Icons.inventory_2_outlined,
              note: d.hiddenListings > 0
                  ? '${d.hiddenListings} hidden by admin'
                  : 'Visible to buyers now',
            ),
            StatCard(
              label: 'Orders This Month',
              value: '${d.ordersThisMonth}',
              icon: Icons.shopping_cart_outlined,
              note: '${d.pendingOrders} pending',
            ),
            StatCard(
              label: 'Revenue',
              value: money(d.revenueThisMonth),
              icon: Icons.payments_outlined,
              note: 'Completed orders this month',
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [activity, const SizedBox(height: 20), links],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: activity),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: links),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _link(String text, AdminSection s) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        side: const BorderSide(color: TamuColors.line),
        foregroundColor: TamuColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => widget.onOpen(s),
      child: Text(
        '$text  →',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
  );
}
