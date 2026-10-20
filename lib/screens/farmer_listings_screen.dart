import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme.dart';
import '../widgets/farmer_bottom_nav.dart';
import 'add_crop_screen.dart' as add_crop;

/// Farmer's own listings, separated from the dashboard to match the Figma tab.
class FarmerListingsScreen extends StatefulWidget {
  const FarmerListingsScreen({super.key});

  @override
  State<FarmerListingsScreen> createState() => _FarmerListingsScreenState();
}

class _FarmerListingsScreenState extends State<FarmerListingsScreen> {
  late Future<List<Product>> _productsFuture;
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _productsFuture = ApiService.fetchMyProducts();
  }

  Future<void> _refresh() async {
    setState(() => _productsFuture = ApiService.fetchMyProducts());
    await _productsFuture;
  }

  bool _isEnded(Product product) {
    final until = product.availableUntil;
    final hasEnded = until != null &&
        DateUtils.dateOnly(DateTime.now()).isAfter(DateUtils.dateOnly(until));
    return product.isOutOfStock || hasEnded;
  }

  bool _isSampleAccount() {
    const demoEmails = {
      'siti@tamu.my',
      'jumat@tamu.my',
      'gundoh@tamu.my',
    };
    return demoEmails.contains(ApiService.currentUser?.email.toLowerCase());
  }

  Future<void> _openCrop({Product? existing}) async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => add_crop.AddCropScreen(existing: existing),
      ),
    );
    if (!mounted || name == null) return;
    await _refresh();
    if (!mounted) return;
    final action = existing == null ? 'added' : 'updated';
    _snack('$name $action', TamuColors.primary);
  }

  Future<void> _delete(Product product) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text('"${product.name}" will be removed from the marketplace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep listing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: TamuColors.danger)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ApiService.deleteProduct(product.id);
      if (!mounted) return;
      await _refresh();
      if (mounted) _snack('${product.name} deleted', TamuColors.primary);
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
      }
    }
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
            child: Column(
              children: [
                _buildHeader(),
                _buildFilters(),
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
                        final all = snapshot.data ?? [];
                        final products = all
                            .where((p) => _filter == 'active' ? !_isEnded(p) : _isEnded(p))
                            .toList();
                        if (products.isEmpty) return _buildEmpty();
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                          children: [
                            ...products.map(_buildListingCard),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: ElevatedButton.icon(
                    onPressed: () => _openCrop(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a crop listing'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: FarmerBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) navigateToFarmerTab(context, index);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My listings',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                FutureBuilder<List<Product>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length;
                    final plural = count == 1 ? '' : 's';
                    final sampleSuffix =
                        _isSampleAccount() ? ' · Sample data' : '';
                    final label = count == null
                        ? 'Your crop listings'
                        : '$count crop$plural';
                    return Text(
                      '$label$sampleSuffix',
                      style: const TextStyle(
                          fontSize: 12, color: TamuColors.textSecondary),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'Add crop',
            onPressed: () => _openCrop(),
            style: IconButton.styleFrom(
              backgroundColor: TamuColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        final activeCount = products.where((p) => !_isEnded(p)).length;
        final endedCount = products.where(_isEnded).length;
        return Container(
          color: TamuColors.background,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            children: [
              _filterChip('active', 'Active $activeCount'),
              const SizedBox(width: 8),
              _filterChip('ended', 'Ended $endedCount'),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: TamuColors.darkGreen,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? TamuColors.darkGreen : TamuColors.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : TamuColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildListingCard(Product product) {
    final ended = _isEnded(product);
    final emoji = switch (product.category) {
      'vegetable' => '🥬',
      'fruit' => '🍌',
      'rice' => '🌾',
      'herb' => '🌿',
      _ => '🌱',
    };
    final availability = product.availableUntil == null
        ? ''
        : ' · Ends ${MaterialLocalizations.of(context).formatShortDate(product.availableUntil!)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TamuColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TamuColors.lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _openCrop(existing: product),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'RM ${product.pricePerUnit.toStringAsFixed(2)} / ${product.unit}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatUnitQuantity(product.stockQuantity, product.unit)}$availability',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ended ? TamuColors.textSecondary : TamuColors.textPrimary,
                      ),
                    ),
                    if (product.hasArModel)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text('◇ Ready-made 3D model',
                            style: TextStyle(fontSize: 9, color: TamuColors.primary)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              _statusBadge(ended ? 'Ended' : 'Active'),
              PopupMenuButton<String>(
                tooltip: 'Listing actions',
                onSelected: (value) {
                  if (value == 'edit') _openCrop(existing: product);
                  if (value == 'delete') _delete(product);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit listing')),
                  PopupMenuItem(value: 'delete', child: Text('Delete listing')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.more_horiz, color: TamuColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _statusBadge(String label) {
    final ended = label == 'Ended';
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ended ? const Color(0xFFEEEEEE) : TamuColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: ended ? TamuColors.textSecondary : TamuColors.primary)),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 65, 20, 20),
      children: [
        const Center(child: Text('🌱', style: TextStyle(fontSize: 42))),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _filter == 'active' ? 'No active listings' : 'No ended listings',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text('Your crop listings will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: TamuColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 42),
        const Icon(Icons.wifi_off, size: 48, color: TamuColors.textSecondary),
        const SizedBox(height: 10),
        const Text('Could not load your listings',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(message.replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: TamuColors.danger)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _refresh, child: const Text('Try again')),
      ],
    );
  }
}
