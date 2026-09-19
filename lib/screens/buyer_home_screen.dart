import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';

/// Buyer marketplace home.
/// Loads REAL products from the FastAPI backend.
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  late Future<List<Product>> _productsFuture;
  String _category = 'All';
  String _search = '';

  static const _categories = ['All', 'vegetable', 'fruit', 'rice'];

  @override
  void initState() {
    super.initState();
    _productsFuture = ApiService.fetchProducts();
  }

  Future<void> _refresh() async {
    setState(() {
      _productsFuture = ApiService.fetchProducts();
    });
    await _productsFuture;
  }

  List<Product> _filter(List<Product> all) {
    return all.where((p) {
      final matchCat = _category == 'All' || p.category == _category;
      final matchSearch =
          _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<Product>>(
                      future: _productsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return _buildError(snapshot.error.toString());
                        }
                        final products = _filter(snapshot.data ?? []);
                        if (products.isEmpty) {
                          return const Center(
                            child: Text('No produce found.',
                                style: TextStyle(fontSize: 16)),
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.all(TamuSizes.pagePadding),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: TamuSizes.gap,
                            mainAxisSpacing: TamuSizes.gap,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, i) =>
                              _ProductCard(product: products[i]),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: TamuColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌿', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TAMU',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('📍 Tamparuli, Sabah',
                        style: TextStyle(fontSize: 13, color: Color(0xFFA5D6A7))),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Search fresh produce...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = _categories[i];
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(
                    c == 'All' ? 'All' : '${_emoji(c)} ${_label(c)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: selected ? TamuColors.primary : Colors.white,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  selectedColor: Colors.white,
                  shape: const StadiumBorder(side: BorderSide(color: Colors.white38)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _emoji(String c) => switch (c) {
        'vegetable' => '🥬',
        'fruit' => '🍌',
        'rice' => '🌾',
        _ => '',
      };

  static String _label(String c) => switch (c) {
        'vegetable' => 'Vegetables',
        'fruit' => 'Fruits',
        'rice' => 'Rice',
        _ => c,
      };

  Widget _buildError(String msg) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.wifi_off, size: 56, color: TamuColors.textSecondary),
        const SizedBox(height: 12),
        const Text(
          'Cannot reach the backend',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Make sure uvicorn is running in your other terminal:\n'
          'uvicorn main:app --reload',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: TamuColors.textSecondary),
        ),
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

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder image area (real photos come later).
          Container(
            height: 90,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: TamuColors.lightGreen,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(TamuSizes.cardRadius)),
            ),
            child: Center(
              child: Text(
                switch (product.category) {
                  'vegetable' => '🥬',
                  'fruit' => '🍌',
                  'rice' => '🌾',
                  _ => '🌱',
                },
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  product.farmerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: TamuColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'RM ${product.pricePerKg.toStringAsFixed(2)} /kg',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TamuColors.primary),
                ),
                const SizedBox(height: 4),
                _stockBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBadge() {
    late final Color bg;
    late final Color fg;
    late final String text;

    if (product.isOutOfStock) {
      bg = const Color(0xFFFFEBEE);
      fg = TamuColors.danger;
      text = 'Out of stock';
    } else if (product.isLowStock) {
      bg = const Color(0xFFFFF8E1);
      fg = TamuColors.warning;
      text = 'Low: ${product.stockKg} kg';
    } else {
      bg = TamuColors.lightGreen;
      fg = TamuColors.primary;
      text = '${product.stockKg} kg available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
