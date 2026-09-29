import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'add_crop_screen.dart';
import 'orders_screen.dart';
import 'sales_report_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'requests_screen.dart';

/// Farmer dashboard - shows ONLY the logged-in farmer's own crops.
class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  late Future<List<Product>> _productsFuture;
    late Future<Badges> _badgesFuture;

  @override
  void initState() {
    super.initState();
    // /products/mine - not /products. This is the ownership fix.
    _productsFuture = ApiService.fetchMyProducts();
    _badgesFuture = ApiService.fetchBadges();
  }

  Future<void> _refresh() async {
    // Braces, not '=>'. An arrow function returns its value, and
    // setState() must never be given a Future.
    setState(() {
      _productsFuture = ApiService.fetchMyProducts();
      _badgesFuture = ApiService.fetchBadges();
    });
    await _productsFuture;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _openAddCrop() async {
    // The form returns the crop name on success, or null if cancelled.
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const AddCropScreen()),
    );
    if (!mounted || name == null) return;
    await _refresh();
    if (!mounted) return;
    _snack('$name added successfully!', TamuColors.primary);
  }

  Future<void> _openEditCrop(Product product) async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AddCropScreen(existing: product)),
    );
    if (!mounted || name == null) return;
    await _refresh();
    if (!mounted) return;
    _snack('$name updated!', TamuColors.primary);
  }

  Future<void> _confirmDelete(Product product) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this crop?'),
        content: Text(
          '"${product.name}" will be removed from the marketplace. '
          'This cannot be undone.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(fontSize: 16, color: TamuColors.danger)),
          ),
        ],
      ),
    );

    if (yes != true) return;

    try {
      await ApiService.deleteProduct(product.id);
      if (!mounted) return;
      _snack('${product.name} deleted', TamuColors.primary);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  /// Opens the incoming orders inbox. Accepting an order changes stock,
  /// so we refresh the dashboard when we come back.
  Future<void> _openOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrdersScreen()),
    );
    if (mounted) await _refresh();
  }

  /// Opens the profile. If the name changed, listings show the new
  /// farmer name, so refresh when we come back.
  Future<void> _openProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (mounted && changed == true) await _refresh();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }
                final products = snapshot.data ?? [];
                final lowStock = products.where((p) => p.isLowStock).toList();

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: const EdgeInsets.all(TamuSizes.pagePadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryGrid(products, lowStock.length),
                            const SizedBox(height: 20),
                            if (lowStock.isNotEmpty) ...[
                              _buildLowStockAlert(lowStock),
                              const SizedBox(height: 20),
                            ],
                            const Text('My Listings',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: TamuSizes.gap),
                            if (products.isEmpty)
                              _buildEmptyState()
                            else
                              ...products.map(_buildListingTile),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _openAddCrop,
                              icon: const Icon(Icons.add),
                              label: const Text('Add New Crop'),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }


    /// FR8: header icons with live red count badges.
  Widget _buildHeaderIcons() {
    return FutureBuilder<Badges>(
      future: _badgesFuture,
      builder: (context, snap) {
        final b = snap.data ?? const Badges();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _badgeIcon(
              icon: Icons.notifications_outlined,
              tooltip: 'Notifications',
              count: b.unreadNotifications,
              onPressed: _openNotifications,
            ),
            _badgeIcon(
              icon: Icons.campaign_outlined,
              tooltip: 'Crop Requests',
              count: b.openRequests,
              onPressed: _openRequests,
            ),
            _badgeIcon(
              icon: Icons.receipt_long_outlined,
              tooltip: 'Incoming Orders',
              count: b.pendingOrders,
              onPressed: _openOrders,
            ),
            IconButton(
              tooltip: 'Sales Report',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesReportScreen()),
              ),
              icon: const Icon(Icons.bar_chart, color: Colors.white),
            ),
            IconButton(
              tooltip: 'My Profile',
              visualDensity: VisualDensity.compact,
              onPressed: _openProfile,
              icon: const Icon(Icons.person_outline, color: Colors.white),
            ),
          ],
        );
      },
    );
  }

  /// Reusable header icon with an optional red count badge.
  Widget _badgeIcon({
    required IconData icon,
    required String tooltip,
    required int count,
    required VoidCallback onPressed,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: Colors.white),
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: BoxDecoration(
                color: TamuColors.danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) {
      setState(() {
        _badgesFuture = ApiService.fetchBadges();
      });
    }
  }

  Future<void> _openRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RequestsScreen()),
    );
    if (mounted) {
      setState(() {
        _badgesFuture = ApiService.fetchBadges();
      });
    }
  }

  Widget _buildHeader() {
    final name = ApiService.currentUser?.fullName ?? 'Farmer';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: TamuColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_greeting 🌾',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFFA5D6A7))),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Text('📍 Tamparuli, Sabah',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Color(0xFFA5D6A7))),
              ],
            ),
          ),
          _buildHeaderIcons(),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<Product> products, int lowCount) {
    final totalStock = products.fold<int>(0, (sum, p) => sum + p.stockKg);
    final totalValue =
        products.fold<double>(0, (sum, p) => sum + (p.pricePerKg * p.stockKg));

    // mainAxisExtent gives every card the SAME fixed height, so the
    // layout cannot overflow when the device uses a larger text scale.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: TamuSizes.gap,
      mainAxisSpacing: TamuSizes.gap,
      childAspectRatio: 1.45,
      children: [
        _summaryCard('Active Listings', '${products.length}',
            Icons.inventory_2_outlined, TamuColors.primary),
        _summaryCard('Low Stock', '$lowCount', Icons.warning_amber_outlined,
            TamuColors.warning),
        _summaryCard('Total Stock', '$totalStock kg', Icons.scale_outlined,
            TamuColors.info),
        _summaryCard('Stock Value', 'RM ${totalValue.toStringAsFixed(0)}',
            Icons.payments_outlined, TamuColors.primary),
      ],
    );
  }

   Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          // FittedBox shrinks long values (e.g. "RM 12345") instead of
          // letting them overflow the card.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: TamuColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert(List<Product> lowStock) {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: TamuColors.warning, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Low Stock Alert',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  lowStock.map((p) => '${p.name} (${p.stockKg} kg)').join(', '),
                  style: const TextStyle(
                      fontSize: 14, color: TamuColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: const Column(
        children: [
          Text('🌱', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text('No crops listed yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Tap "Add New Crop" to list your first produce',
              style: TextStyle(fontSize: 14, color: TamuColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildListingTile(Product p) {
    return Container(
      margin: const EdgeInsets.only(bottom: TamuSizes.gap),
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: TamuColors.lightGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                switch (p.category) {
                  'vegetable' => '🥬',
                  'fruit' => '🍌',
                  'rice' => '🌾',
                  'herb' => '🌿',
                  _ => '🌱',
                },
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  'RM ${p.pricePerKg.toStringAsFixed(2)} /kg  ·  ${p.stockKg} kg',
                  style: TextStyle(
                    fontSize: 14,
                    color: p.isOutOfStock
                        ? TamuColors.danger
                        : p.isLowStock
                            ? TamuColors.warning
                            : TamuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Edit + Delete - only visible to the owner, because this whole
          // screen only ever shows the logged-in farmer's own crops.
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _openEditCrop(p),
            icon: const Icon(Icons.edit_outlined, color: TamuColors.info),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(p),
            icon: const Icon(Icons.delete_outline, color: TamuColors.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.wifi_off, size: 56, color: TamuColors.textSecondary),
        const SizedBox(height: 12),
        const Text('Cannot reach the backend',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Run: uvicorn main:app --reload',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: TamuColors.textSecondary)),
        const SizedBox(height: 16),
        Text(msg.replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: TamuColors.danger)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
      ],
    );
  }
}
