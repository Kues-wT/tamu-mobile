import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'add_crop_screen.dart';
import 'orders_screen.dart';
import 'sales_report_screen.dart';
import 'profile_screen.dart';


/// Farmer dashboard - shows ONLY the logged-in farmer's own crops.
class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    // /products/mine - not /products. This is the ownership fix.
    _productsFuture = ApiService.fetchMyProducts();
  }

  Future<void> _refresh() async {
    // Braces, not '=>'. An arrow function returns its value, and
    // setState() must never be given a Future.
    setState(() {
      _productsFuture = ApiService.fetchMyProducts();
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
                Text('$_greeting, $name 🌾',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 2),
                const Text('📍 Tamparuli, Sabah',
                    style: TextStyle(fontSize: 13, color: Color(0xFFA5D6A7))),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sales Report',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SalesReportScreen()),
            ),
            icon: const Icon(Icons.bar_chart, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Incoming Orders',
            onPressed: _openOrders,
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'My Profile',
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<Product> products, int lowCount) {
    final totalStock = products.fold<int>(0, (sum, p) => sum + p.stockKg);
    final totalValue =
        products.fold<double>(0, (sum, p) => sum + (p.pricePerKg * p.stockKg));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: TamuSizes.gap,
      mainAxisSpacing: TamuSizes.gap,
      childAspectRatio: 1.6,
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
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: TamuColors.textSecondary)),
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