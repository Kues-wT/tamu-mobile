import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'product_detail_screen.dart';
import 'orders_screen.dart';
import 'nearby_farms_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'requests_screen.dart';

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
  bool _nearbyOnly = false;      // FR3: filter by proximity
  double _radiusKm = 10;
  late Future<Badges> _badgesFuture;

  static const _categories = ['All', 'vegetable', 'fruit', 'rice'];

  @override
  void initState() {
    super.initState();
    _productsFuture = _load();
    _badgesFuture = ApiService.fetchBadges();
  }

  /// Always asks the backend for distances, measured from the buyer's
  /// saved location (or Tamparuli town if they have not set one).
  Future<List<Product>> _load() {
    final user = ApiService.currentUser;
    return ApiService.fetchProducts(
      lat: user?.latitude ?? kTamparuliLat,
      lng: user?.longitude ?? kTamparuliLng,
      radiusKm: _nearbyOnly ? _radiusKm : null,
      sort: 'distance',
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _productsFuture = _load();
      _badgesFuture = ApiService.fetchBadges();
    });
    await _productsFuture;
  }

  Future<void> _openNearbyFarms() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NearbyFarmsScreen()),
    );
    if (mounted) await _refresh();
  }

  /// Opens the detail page. If an order was placed it returns the crop
  /// name, so we reload (stock may have changed) and confirm to the user.
  Future<void> _openProduct(Product p) async {
    final orderedName = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
    );
    if (!mounted || orderedName == null) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: TamuColors.primary,
        content: Text(
          'Order placed for $orderedName!',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: _openOrders,
        ),
      ),
    );
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrdersScreen()),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (mounted) setState(() {});
  }

  List<Product> _filter(List<Product> all) {
    return all.where((p) {
      final matchCat = _category == 'All' || p.category == _category;
      final matchSearch = _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase());
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _buildError(snapshot.error.toString());
                        }
                        final products = _filter(snapshot.data ?? []);
                        if (products.isEmpty) {
                          return ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No produce found.',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Try widening the distance filter.',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: TamuColors.textSecondary),
                                ),
                              ),
                            ],
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
                          itemBuilder: (context, i) {
                            final product = products[i];
                            return _ProductCard(
                              product: product,
                              onTap: () => _openProduct(product),
                            );
                          },
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

    /// FR8: header icons with live red count badges.
  Widget _buildHeaderIcons() {
    return FutureBuilder<Badges>(
      future: _badgesFuture,
      builder: (context, snap) {
        final bg = snap.data ?? const Badges();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _badgeIcon(
              icon: Icons.notifications_outlined,
              tooltip: 'Notifications',
              count: bg.unreadNotifications,
              onPressed: _openNotifications,
            ),
            _badgeIcon(
              icon: Icons.campaign_outlined,
              tooltip: 'Crop Requests',
              count: bg.openRequests,
              onPressed: _openRequests,
            ),
            _badgeIcon(
              icon: Icons.receipt_long_outlined,
              tooltip: 'My Orders',
              count: bg.pendingOrders,
              onPressed: _openOrders,
            ),
            IconButton(
              tooltip: 'Nearby Farms',
              visualDensity: VisualDensity.compact,
              onPressed: _openNearbyFarms,
              icon: const Icon(Icons.map_outlined, color: Colors.white),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TAMU',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '📍 Tamparuli  ·  ${ApiService.currentUser?.fullName ?? ""}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA5D6A7),
                      ),
                    ),
                  ],
                ),
              ),
            _buildHeaderIcons(),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() {
              _search = v;
            }),
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Search fresh produce...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.near_me_outlined,
                  size: 17, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Text(
                _nearbyOnly
                    ? 'Within ${_radiusKm.toStringAsFixed(0)} km'
                    : 'All distances',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              if (_nearbyOnly) ...[
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (v) => setState(() {
                        _radiusKm = v;
                      }),
                      onChangeEnd: (_) => _refresh(),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              Switch(
                value: _nearbyOnly,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF81C784),
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
                onChanged: (v) {
                  setState(() {
                    _nearbyOnly = v;
                  });
                  _refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = _categories[i];
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(
                    c == 'All' ? 'All' : '${_emoji(c)} ${_label(c)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? TamuColors.primary
                          : TamuColors.textPrimary,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  backgroundColor: Colors.white,
                  selectedColor: Colors.white,
                  side: BorderSide(
                    color: selected ? TamuColors.primary : TamuColors.border,
                    width: selected ? 2 : 1,
                  ),
                  onSelected: (_) => setState(() {
                    _category = c;
                  }),
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
        Text(
          msg.replaceFirst('Exception: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: TamuColors.danger),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      child: Container(
        decoration: BoxDecoration(
          color: TamuColors.surface,
          borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
          border: Border.all(color: TamuColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: TamuColors.lightGreen,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(TamuSizes.cardRadius),
                ),
              ),
              child: Center(
                child: Text(
                  switch (product.category) {
                    'vegetable' => '🥬',
                    'fruit' => '🍌',
                    'rice' => '🌾',
                    'herb' => '🌿',
                    _ => '🌱',
                  },
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      product.farmName ?? product.farmerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: TamuColors.textSecondary,
                      ),
                    ),
                    if (product.distanceKm != null)
                      Row(
                        children: [
                          const Icon(Icons.near_me,
                              size: 12, color: TamuColors.info),
                          const SizedBox(width: 3),
                          Text(
                            '${product.distanceKm!.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TamuColors.info),
                          ),
                        ],
                      ),
                    const Spacer(),
                    Text(
                      'RM ${product.pricePerKg.toStringAsFixed(2)} /kg',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TamuColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _stockBadge(),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}