import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'product_detail_screen.dart';
import 'orders_screen.dart' as orders;
import 'nearby_farms_screen.dart';
import 'profile_screen.dart' as profile;
import 'notifications_screen.dart' as notifications;
import 'requests_screen.dart' as requests;

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

  /// Opens the detail page. Ordering now ends on the Order placed screen,
  /// so just reload when the buyer comes back (badges/stock may change).
  Future<void> _openProduct(Product p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const orders.OrdersScreen()),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const profile.ProfileScreen()),
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
        bottom: false,
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
                          return ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: CircularProgressIndicator()),
                            ],
                          );
                        }
                        if (snapshot.hasError) {
                          return _buildError(snapshot.error.toString());
                        }
                        final products = _filter(snapshot.data ?? []);
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text('Browse crops',
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      _sampleDataBadge(),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Illustrative listings near Tamparuli',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: TamuColors.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildCategoryChips(),
                                  const SizedBox(height: 10),
                                  _buildExploreFarmsCard(),
                                ],
                              ),
                            ),
                            if (products.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 30),
                                child: Center(
                                  child: Text(
                                    'No produce found. Try another search or category.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: TamuColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: Column(
                                  children: products
                                      .map((product) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 9),
                                            child: _ProductCard(
                                              product: product,
                                              onTap: () => _openProduct(product),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
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
      bottomNavigationBar: _buildBuyerBottomNav(),
    );
  }


  /// Figma-style notification button with an unread badge.
  Widget _buildHeaderIcons() {
    return FutureBuilder<Badges>(
      future: _badgesFuture,
      builder: (context, snap) {
        final unread = snap.data?.unreadNotifications ?? 0;
        return InkWell(
          onTap: _openNotifications,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none,
                    color: Colors.white, size: 23),
                if (unread > 0)
                  Positioned(
                    right: 1,
                    top: 0,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: TamuColors.warning,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: TamuColors.darkGreen),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const notifications.NotificationsScreen()),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 18),
      color: TamuColors.darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TAMU TAMPARULI AREA',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: TamuColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Fresh nearby',
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderIcons(),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 12, right: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: TamuColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _search = value),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search Pak Choy, Tuhau...',
                      border: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openFilterSheet,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(52, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: TamuColors.lightGreen,
                    foregroundColor: TamuColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Filter',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    var nearbyOnly = _nearbyOnly;
    var radius = _radiusKm;
    var applied = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter nearby produce',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show farms near me'),
                  subtitle: const Text('Use your saved location or Tamparuli centre'),
                  value: nearbyOnly,
                  onChanged: (value) => setSheetState(() => nearbyOnly = value),
                ),
                if (nearbyOnly) ...[
                  Text('Within ${radius.toStringAsFixed(0)} km',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: radius,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '${radius.toStringAsFixed(0)} km',
                    onChanged: (value) => setSheetState(() => radius = value),
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    applied = true;
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('Apply filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied && mounted) {
      setState(() {
        _nearbyOnly = nearbyOnly;
        _radiusKm = radius;
        _productsFuture = _load();
      });
    }
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = _category == category;
          final label = switch (category) {
            'All' => 'All',
            'vegetable' => 'Vegetables',
            'fruit' => 'Fruits',
            'rice' => 'Rice',
            _ => category,
          };
          return ChoiceChip(
            label: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : TamuColors.textPrimary,
                )),
            selected: selected,
            showCheckmark: false,
            selectedColor: TamuColors.darkGreen,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? TamuColors.darkGreen : TamuColors.border),
            onSelected: (_) => setState(() => _category = category),
          );
        },
      ),
    );
  }

  Widget _sampleDataBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: TamuColors.secondary),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text('SAMPLE DATA',
          style: TextStyle(
              fontSize: 8,
              letterSpacing: 0.7,
              fontWeight: FontWeight.bold,
              color: TamuColors.darkGreen)),
    );
  }

  Widget _buildExploreFarmsCard() {
    return InkWell(
      onTap: _openNearbyFarms,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: TamuColors.lightGreen,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: TamuColors.primary, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore nearby farms',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: TamuColors.primary)),
                  SizedBox(height: 2),
                  Text('View public pickup points near Tamparuli',
                      style: TextStyle(
                          fontSize: 10, color: TamuColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: TamuColors.primary),
          ],
        ),
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
            _buyerNavItem(Icons.storefront_outlined, 'Market', true, () {}),
            _buyerNavItem(Icons.receipt_long_outlined, 'Orders', false, _openOrders),
            _buyerNavItem(Icons.forum_outlined, 'Requests', false, _openRequests),
            _buyerNavItem(Icons.person_outline, 'Profile', false, _openProfile),
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

  String get _availabilityLabel {
    final today = DateUtils.dateOnly(DateTime.now());
    final from = product.availableFrom;
    final until = product.availableUntil;
    if (until != null && today.isAfter(DateUtils.dateOnly(until))) {
      return 'Ended';
    }
    if (from != null && today.isBefore(DateUtils.dateOnly(from))) {
      return 'Upcoming';
    }
    if (product.isOutOfStock) return 'Unavailable';
    return 'Available';
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = _availabilityLabel == 'Available';
    final imageEmoji = switch (product.category) {
      'vegetable' => '🥬',
      'fruit' => '🍌',
      'rice' => '🌾',
      'herb' => '🌿',
      _ => '🌱',
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: TamuColors.border),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TamuColors.lightGreen,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(imageEmoji, style: const TextStyle(fontSize: 37)),
                  ),
                  if (product.hasArModel)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text('3D / AR',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: TamuColors.darkGreen)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: TamuColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? TamuColors.lightGreen
                                : const Color(0xFFFFF4DE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _availabilityLabel,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isAvailable
                                  ? TamuColors.primary
                                  : TamuColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${product.pricePerUnit.toStringAsFixed(2)} / ${product.unit}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: TamuColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatUnitQuantity(product.stockQuantity, product.unit)} available',
                      style: const TextStyle(
                          fontSize: 11, color: TamuColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: TamuColors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${product.farmName ?? product.farmerName}'
                            '${product.distanceKm == null ? '' : ' - ${product.distanceKm!.toStringAsFixed(1)} km'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10,
                                color: TamuColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right, color: TamuColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
