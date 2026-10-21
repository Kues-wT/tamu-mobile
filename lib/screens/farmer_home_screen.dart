import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme.dart';
import '../widgets/farmer_bottom_nav.dart';
import 'add_crop_screen.dart' as add_crop;
import 'notifications_screen.dart' as notifications;
import 'requests_screen.dart' as requests;
import 'sales_report_screen.dart' as reports;

/// Farmer dashboard. Farmer listings and orders are separate tabs.
class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  late Future<Badges> _badgesFuture;
  late Future<SalesReport> _salesFuture;
  late Future<List<Order>> _attentionOrdersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _badgesFuture = ApiService.fetchBadges();
    _salesFuture = ApiService.fetchSalesReport(months: 6);
    _attentionOrdersFuture = ApiService.fetchOrders(status: 'pending');
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _badgesFuture,
      _salesFuture,
      _attentionOrdersFuture,
    ]);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String get _dateLabel {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1].toUpperCase()}, '
        '${now.day} ${months[now.month - 1].toUpperCase()}';
  }

  bool get _isSampleAccount {
    const demoEmails = {
      'siti@tamu.my',
      'jumat@tamu.my',
      'gundoh@tamu.my',
    };
    return demoEmails.contains(ApiService.currentUser?.email.toLowerCase());
  }

  Future<void> _openAddCrop() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const add_crop.AddCropScreen()),
    );
    if (!mounted || name == null) return;
    await _refresh();
    if (mounted) _snack('$name added successfully', TamuColors.primary);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const notifications.NotificationsScreen()),
    );
    if (mounted) {
      setState(() {
        _badgesFuture = ApiService.fetchBadges();
      });
    }
  }

  Future<void> _openRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const requests.RequestsScreen()),
    );
    if (mounted) {
      setState(() {
        _badgesFuture = ApiService.fetchBadges();
      });
    }
  }

  void _openListings() {
    Navigator.of(context).pushNamed('/farmer/listings');
  }

  void _openOrders() {
    Navigator.of(context).pushNamed('/farmer/orders');
  }

  void _openReport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const reports.SalesReportScreen()),
    );
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isSampleAccount) _buildSampleDataLabel(),
                        _buildSalesCard(),
                        const SizedBox(height: 10),
                        _buildAttentionCounts(),
                        const SizedBox(height: 18),
                        _buildSectionHeading('Quick actions', 'Common tasks'),
                        const SizedBox(height: 10),
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        _buildNeedsAttentionHeading(),
                        const SizedBox(height: 10),
                        _buildNeedsAttention(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: FarmerBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index != 0) navigateToFarmerTab(context, index);
        },
      ),
    );
  }

  Widget _buildHeader() {
    final user = ApiService.currentUser;
    final farmerName = user?.fullName ?? 'Farmer';
    final farmName = user?.farmName?.trim().isNotEmpty == true
        ? user!.farmName!.trim()
        : (user?.fullName ?? 'Your farm');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 24),
      decoration: const BoxDecoration(
        color: TamuColors.darkGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateLabel,
                    style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                        color: TamuColors.secondary)),
                const SizedBox(height: 8),
                Text('$_greeting, $farmerName',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(farmName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFA5D6A7))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _notificationButton(),
        ],
      ),
    );
  }

  Widget _notificationButton() {
    return FutureBuilder<Badges>(
      future: _badgesFuture,
      builder: (context, snapshot) {
        final count = snapshot.data?.unreadNotifications ?? 0;
        return InkWell(
          onTap: _openNotifications,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none,
                    color: TamuColors.darkGreen, size: 23),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: TamuColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: TamuColors.darkGreen)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSampleDataLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: TamuColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('SAMPLE DATA',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                    color: TamuColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          const Text('Illustrative business data',
              style: TextStyle(fontSize: 10, color: TamuColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSalesCard() {
    return FutureBuilder<SalesReport>(
      future: _salesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSalesUnavailable();
        }
        if (!snapshot.hasData) {
          return Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TamuColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const CircularProgressIndicator(color: Colors.white),
          );
        }
        final report = snapshot.data!;
        final maxRevenue = report.monthly.fold<double>(
          0,
          (maxValue, item) => math.max(maxValue, item.revenue).toDouble(),
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 10),
          decoration: BoxDecoration(
            color: TamuColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Sales this month',
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: _openReport,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('View report  ›',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              Text('RM ${report.thisMonthRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text('${report.thisMonthOrders} completed orders',
                  style: const TextStyle(fontSize: 13, color: Colors.white)),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final month in report.monthly)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: maxRevenue <= 0
                              ? 4
                              : math
                                  .max(4.0, 30 * month.revenue / maxRevenue)
                                  .toDouble(),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.24),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesUnavailable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TamuColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('Sales summary is unavailable right now.',
                style: TextStyle(fontSize: 14, color: Colors.white)),
          ),
          TextButton(
            onPressed: _openReport,
            child: const Text('View report',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionCounts() {
    return FutureBuilder<Badges>(
      future: _badgesFuture,
      builder: (context, snapshot) {
        final badges = snapshot.data ?? const Badges();
        return Row(
          children: [
            Expanded(
              child: _countCard(
                icon: Icons.receipt_long_outlined,
                count: badges.pendingOrders,
                label: 'Pending orders',
                color: TamuColors.warning,
                onTap: _openOrders,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _countCard(
                icon: Icons.forum_outlined,
                count: badges.openRequests,
                label: 'Open requests',
                color: TamuColors.primary,
                onTap: _openRequests,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _countCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 78,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TamuColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const Spacer(),
                  Text('$count',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: TamuColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(fontSize: 11, color: TamuColors.textSecondary)),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
              Icons.add, 'Add crop', _openAddCrop, TamuColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quickAction(
              Icons.eco_outlined, 'My listings', _openListings, TamuColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quickAction(Icons.receipt_long_outlined, 'Manage orders',
              _openOrders, TamuColors.primary),
        ),
      ],
    );
  }

  Widget _quickAction(
      IconData icon, String label, VoidCallback onTap, Color color) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TamuColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeedsAttentionHeading() {
    return Row(
      children: [
        const Expanded(
          child: Text('Needs your attention',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: _openOrders,
          child: const Text('View all'),
        ),
      ],
    );
  }

  Widget _buildNeedsAttention() {
    return FutureBuilder<List<Order>>(
      future: _attentionOrdersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.hasError) {
          return _simpleInfoCard('Unable to load pending orders. Tap View all to retry.');
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return _simpleInfoCard('No pending orders right now.');
        }
        final order = orders.first;
        final name = order.productName ?? 'Crop order';
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _openOrders,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TamuColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 18, color: TamuColors.warning),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${formatUnitQuantity(order.quantity, order.unit)} · '
                          'RM ${order.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 10, color: TamuColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Pending',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: TamuColors.warning)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _simpleInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TamuColors.border),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: TamuColors.textSecondary)),
    );
  }
}
