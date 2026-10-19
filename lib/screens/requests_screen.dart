import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'orders_screen.dart' as orders;
import 'profile_screen.dart' as profile;
import 'notifications_screen.dart' as notifications;

/// FR6 - Crop Request Board.
/// Buyers post requests for produce nobody has listed; farmers browse
/// the open requests and accept the ones they can supply.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late Future<List<CropRequest>> _future;
  String _filter = 'open';
  int? _busyId;

  static const _filters = ['open', 'accepted', 'all'];

  bool get _isFarmer => ApiService.currentUser?.isFarmer ?? false;
  bool get _isBuyer => ApiService.currentUser?.isBuyer ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ApiService.fetchRequests(
      status: _filter == 'all' ? null : _filter,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content:
            Text(msg, style: const TextStyle(fontSize: 16, color: Colors.white)),
      ),
    );
  }

  /// FR6 request-to-order conversion.
  /// The farmer picks one of their own listings, and accepting the
  /// request immediately creates a pending order for the buyer.
  Future<void> _accept(CropRequest r) async {
    List<Product> mine = [];
    try {
      mine = await ApiService.fetchMyProducts();
    } catch (_) {
      // If listings cannot be loaded we still allow a plain accept.
    }
    if (!mounted) return;

    // Suggest listings that can actually cover the requested amount.
    final usable = mine.where((p) => p.stockKg >= r.quantityKg).toList();

    final choice = await showDialog<_AcceptChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supply ${r.cropName}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.buyerName} needs ${r.quantityKg} kg.',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              const Text(
                'Link one of your listings to turn this into a real order:',
                style: TextStyle(
                    fontSize: 14, color: TamuColors.textSecondary),
              ),
              const SizedBox(height: 10),
              if (usable.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mine.isEmpty
                        ? 'You have no listings yet.'
                        : 'None of your listings has ${r.quantityKg} kg in '
                            'stock. Add stock first, or just accept and '
                            'arrange it manually.',
                    style: const TextStyle(fontSize: 13),
                  ),
                )
              else
                ...usable.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx)
                            .pop(_AcceptChoice(productId: p.id)),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              'RM ${p.pricePerKg.toStringAsFixed(2)}/kg  ·  '
                              '${p.stockKg} kg in stock  ·  total RM '
                              '${(p.pricePerKg * r.quantityKg).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: TamuColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_AcceptChoice()),
            child: const Text('Accept only', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    setState(() {
      _busyId = r.id;
    });
    try {
      final updated =
          await ApiService.acceptRequest(r.id, productId: choice.productId);
      if (!mounted) return;
      setState(() {
        _busyId = null;
      });
      await _refresh();
      if (!mounted) return;
      _snack(
        updated.convertedOrderId != null
            ? 'Accepted. Order #${updated.convertedOrderId} created - check '
                'Incoming Orders.'
            : 'You accepted the request for ${r.cropName}',
        TamuColors.primary,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
      });
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  Future<void> _cancel(CropRequest r) async {
    setState(() {
      _busyId = r.id;
    });
    try {
      await ApiService.cancelRequest(r.id);
      if (!mounted) return;
      setState(() {
        _busyId = null;
      });
      await _refresh();
      if (!mounted) return;
      _snack('Request withdrawn', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
      });
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  Future<void> _newRequest() async {
    final cropCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request a Crop'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: cropCtrl,
                  style: const TextStyle(fontSize: 16),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Crop Name',
                    hintText: 'e.g. Sayur Sawi',
                    prefixIcon: Icon(Icons.eco_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter the crop name'
                      : null,
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Quantity needed (kg)',
                    hintText: 'e.g. 30',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Whole numbers only';
                    if (n <= 0) return 'Must be more than 0';
                    return null;
                  },
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Max price per kg (optional)',
                    prefixText: 'RM ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Numbers only';
                    if (n <= 0) return 'Must be more than 0';
                    return null;
                  },
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Needed by Friday for my restaurant',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Post', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService.createRequest(
        cropName: cropCtrl.text.trim(),
        quantityKg: int.parse(qtyCtrl.text.trim()),
        maxPricePerKg: double.tryParse(priceCtrl.text.trim()),
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _filter = 'open';
        _load();
      });
      _snack('Your request is now on the board', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const notifications.NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: _isBuyer
          ? null
          : AppBar(
              title: const Text('Buyer Requests'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      floatingActionButton: _isBuyer
          ? FloatingActionButton.extended(
              onPressed: _newRequest,
              backgroundColor: TamuColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Request a Crop'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                if (_isBuyer) _buildBuyerHeader(),
                if (_isFarmer) _buildFirstAcceptanceNote(),
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<CropRequest>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return _buildError(snapshot.error.toString());
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) return _buildEmpty();

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _buildCard(items[i]),
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
      bottomNavigationBar: _isBuyer ? _buildBuyerBottomNav() : null,
    );
  }

  Widget _buildBuyerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Requests',
                    style: TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Ask local farmers for produce you need',
                    style: TextStyle(
                        fontSize: 12, color: TamuColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none,
                color: TamuColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAcceptanceNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TamuColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC6E2C8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: TamuColors.primary, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'First valid acceptance wins. Once one farmer accepts, the request closes for everyone else.',
              style: TextStyle(fontSize: 13, color: TamuColors.textPrimary),
            ),
          ),
        ],
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
            _buyerNavItem(Icons.storefront_outlined, 'Market', false, () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }),
            _buyerNavItem(Icons.receipt_long_outlined, 'Orders', false, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const orders.OrdersScreen()),
              );
            }),
            _buyerNavItem(Icons.forum_outlined, 'Requests', true, () {}),
            _buyerNavItem(Icons.person_outline, 'Profile', false, () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const profile.ProfileScreen()),
              );
            }),
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
            Icon(icon,
                size: 19,
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

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final f in _filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  f[0].toUpperCase() + f.substring(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _filter == f ? Colors.white : TamuColors.textPrimary,
                  ),
                ),
                selected: _filter == f,
                showCheckmark: false,
                selectedColor: TamuColors.primary,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color:
                        _filter == f ? TamuColors.primary : TamuColors.border),
                onSelected: (_) => setState(() {
                  _filter = f;
                  _load();
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(CropRequest r) {
    final busy = _busyId == r.id;
    final mine = r.buyerId == (ApiService.currentUser?.id ?? -1);

    return Container(
      margin: const EdgeInsets.only(bottom: TamuSizes.gap),
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.cropName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _statusBadge(r.status),
            ],
          ),
          const SizedBox(height: 4),
          Text('${r.quantityKg} kg needed',
              style: const TextStyle(fontSize: 16, color: TamuColors.primary)),
          if (r.maxPricePerKg != null)
            Text('Up to RM ${r.maxPricePerKg!.toStringAsFixed(2)} /kg',
                style: const TextStyle(
                    fontSize: 14, color: TamuColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: TamuColors.textSecondary),
              const SizedBox(width: 4),
              Text(mine ? 'You' : r.buyerName,
                  style: const TextStyle(
                      fontSize: 14, color: TamuColors.textSecondary)),
              const Spacer(),
              Text(_timeAgo(r.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: TamuColors.textSecondary)),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.note!, style: const TextStyle(fontSize: 14)),
            ),
          ],
          if (r.status == 'accepted' && r.acceptedByName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 16, color: TamuColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Accepted by ${r.acceptedByName}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: TamuColors.primary)),
                ),
              ],
            ),
            if (r.convertedOrderId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        size: 16, color: TamuColors.info),
                    const SizedBox(width: 6),
                    Text('Became order #${r.convertedOrderId}',
                        style: const TextStyle(
                            fontSize: 13, color: TamuColors.info)),
                  ],
                ),
              ),
          ],
          if (busy) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            if (_isFarmer && r.isOpen) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _accept(r),
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('I can supply this'),
              ),
            ],
            if (mine && r.isOpen) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _cancel(r),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TamuColors.danger,
                  side: const BorderSide(color: TamuColors.danger),
                ),
                child: const Text('Withdraw Request'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (status) {
      case 'open':
        bg = TamuColors.lightGreen;
        fg = TamuColors.primary;
        label = 'Open';
      case 'accepted':
        bg = const Color(0xFFE3F2FD);
        fg = TamuColors.info;
        label = 'Accepted';
      default:
        bg = const Color(0xFFFFEBEE);
        fg = TamuColors.danger;
        label = 'Cancelled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 90),
        const Center(child: Text('📋', style: TextStyle(fontSize: 46))),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _filter == 'open' ? 'No open requests' : 'Nothing here',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _isBuyer
                ? 'Tap "Request a Crop" to ask farmers for produce.'
                : 'Buyer requests will appear here.',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 14, color: TamuColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.campaign_outlined,
            size: 56, color: TamuColors.textSecondary),
        const SizedBox(height: 12),
        const Text('Cannot load requests',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(msg.replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: TamuColors.danger)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
      ],
    );
  }
}

/// What the farmer chose in the accept dialog.
/// productId == null means "accept without creating an order".
class _AcceptChoice {
  final int? productId;
  const _AcceptChoice({this.productId});
}
