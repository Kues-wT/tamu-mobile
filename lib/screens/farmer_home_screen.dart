import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';

/// Farmer dashboard.
/// Shows a summary of the farmer's own listings, pulled from the backend.
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
    _productsFuture = ApiService.fetchProducts();
  }

  Future<void> _refresh() async {
    setState(() => _productsFuture = ApiService.fetchProducts());
    await _productsFuture;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
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
                            ...products.map(_buildListingTile),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Add Crop screen coming next!',
                                        style: TextStyle(fontSize: 16)),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add New Crop'),
                            ),
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
                Text('$_greeting, Farmer 🌾',
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
            tooltip: 'Logout',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<Product> products, int lowCount) {
    final totalStock = products.fold<int>(0, (sum, p) => sum + p.stockKg);
    final totalValue = products.fold<double>(
        0, (sum, p) => sum + (p.pricePerKg * p.stockKg));

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
        _summaryCard('Low Stock', '$lowCount',
            Icons.warning_amber_outlined, TamuColors.warning),
        _summaryCard('Total Stock', '$totalStock kg',
            Icons.scale_outlined, TamuColors.info),
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
              style: const TextStyle(
                  fontSize: 13, color: TamuColors.textSecondary)),
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
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  lowStock
                      .map((p) => '${p.name} (${p.stockKg} kg)')
                      .join(', '),
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
                Text('RM ${p.pricePerKg.toStringAsFixed(2)} /kg',
                    style: const TextStyle(
                        fontSize: 14, color: TamuColors.textSecondary)),
              ],
            ),
          ),
          Text(
            '${p.stockKg} kg',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: p.isOutOfStock
                  ? TamuColors.danger
                  : p.isLowStock
                      ? TamuColors.warning
                      : TamuColors.primary,
            ),
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
        Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: TamuColors.danger)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
      ],
    );
  }
}
