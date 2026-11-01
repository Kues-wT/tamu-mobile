import 'package:flutter/material.dart' hide Text;

import '../i18n.dart';
import '../widgets/skeleton.dart';
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
    ).then(_visibleToMe);
  }

  /// Farmers see the open board plus the requests they accepted
  /// themselves, not ones other farmers accepted.
  List<CropRequest> _visibleToMe(List<CropRequest> all) {
    if (!_isFarmer) return all;
    final me = ApiService.currentUser?.id;
    return all.where((r) => r.isOpen || r.acceptedById == me).toList();
  }

  void _openOrders() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const orders.OrdersScreen()));
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(
          msg,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  /// FR6 bidding: the farmer offers to supply the request from one of
  /// their kg listings, at the listing's price or their own.
  Future<void> _sendOffer(CropRequest r) async {
    List<Product> mine;
    try {
      mine = await ApiService.fetchMyProducts();
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
      }
      return;
    }
    if (!mounted) return;

    // Only listings of the requested crop that can cover the amount and
    // are on sale today (the server refuses the others).
    final today = DateUtils.dateOnly(DateTime.now());
    final usable = mine
        .where(
          (p) =>
              sameCrop(p.name, r.cropName) &&
              p.unit == 'kg' &&
              p.stockQuantity >= r.quantityKg &&
              (p.availableFrom == null || !p.availableFrom!.isAfter(today)) &&
              (p.availableUntil == null || !p.availableUntil!.isBefore(today)),
        )
        .toList();

    final draft = await showDialog<_OfferDraft>(
      context: context,
      builder: (ctx) => _OfferDialog(request: r, listings: usable),
    );
    if (draft == null || !mounted) return;

    setState(() => _busyId = r.id);
    try {
      await ApiService.createOffer(
        r.id,
        productId: draft.productId,
        pricePerKg: draft.pricePerKg,
        note: draft.note,
      );
      if (!mounted) return;
      setState(() => _busyId = null);
      await _refresh();
      if (!mounted) return;
      _snack('Offer sent. The buyer will choose an offer.', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  Future<void> _withdrawOffer(CropRequest r, RequestOffer offer) async {
    setState(() => _busyId = r.id);
    try {
      await ApiService.withdrawOffer(r.id, offer.id);
      if (!mounted) return;
      setState(() => _busyId = null);
      await _refresh();
      if (!mounted) return;
      _snack('Offer withdrawn', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  /// FR6 bidding: the buyer compares the offers and chooses one, which
  /// becomes a pending order.
  Future<void> _showOffers(CropRequest r) async {
    final chosen = await showModalBottomSheet<RequestOffer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _OffersSheet(request: r),
    );
    if (chosen == null || !mounted) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this offer?'),
        content: Text(
          '${chosen.farmerName} supplies ${r.quantityKg} kg of ${r.cropName} '
          'for RM ${chosen.totalPrice.toStringAsFixed(2)}. The other offers '
          'will be declined.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Accept offer'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _busyId = r.id);
    try {
      final updated = await ApiService.acceptOffer(r.id, chosen.id);
      if (!mounted) return;
      setState(() {
        _busyId = null;
        // Show the request where it now lives, with its new order.
        _filter = 'accepted';
      });
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TamuColors.primary,
          content: Text(
            'Order #${updated.convertedOrderId} created. The farmer will '
            'confirm it.',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          action: SnackBarAction(
            label: tr('View order'),
            textColor: Colors.white,
            onPressed: _openOrders,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
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
                  decoration: InputDecoration(
                    labelText: tr('Crop Name'),
                    hintText: tr('e.g. Sayur Sawi'),
                    prefixIcon: Icon(Icons.eco_outlined),
                  ),
                  validator: trValidator(
                    (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter the crop name'
                        : null,
                  ),
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('Quantity needed (kg)'),
                    hintText: tr('e.g. 30'),
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  validator: trValidator((v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Whole numbers only';
                    if (n <= 0) return 'Must be more than 0';
                    return null;
                  }),
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('Max price per kg (optional)'),
                    prefixText: 'RM ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: trValidator((v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null) return 'Numbers only';
                    if (n <= 0) return 'Must be more than 0';
                    return null;
                  }),
                ),
                const SizedBox(height: TamuSizes.gap),
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('Note (optional)'),
                    hintText: tr('e.g. Needed by Friday for my restaurant'),
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
      MaterialPageRoute(
        builder: (_) => const notifications.NotificationsScreen(),
      ),
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
                  tooltip: tr('Refresh'),
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
                          return const SkeletonList(
                            kind: SkeletonKind.request,
                            count: 4,
                          );
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
                Text(
                  'Requests',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2),
                Text(
                  'Ask local farmers for produce you need',
                  style: TextStyle(
                    fontSize: 12,
                    color: TamuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Notifications'),
            onPressed: _openNotifications,
            icon: const Icon(
              Icons.notifications_none,
              color: TamuColors.textPrimary,
            ),
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
              'Send an offer with your price. The buyer chooses one offer, '
              'and the request then closes for everyone else.',
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
                MaterialPageRoute(
                  builder: (_) => const profile.ProfileScreen(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buyerNavItem(
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
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
            Icon(
              icon,
              size: 19,
              color: selected ? TamuColors.primary : TamuColors.textSecondary,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? TamuColors.primary : TamuColors.textSecondary,
              ),
            ),
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
                  color: _filter == f ? TamuColors.primary : TamuColors.border,
                ),
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
                child: Text(
                  r.cropName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _statusBadge(r.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.quantityKg} kg needed',
            style: const TextStyle(fontSize: 16, color: TamuColors.primary),
          ),
          if (r.maxPricePerKg != null)
            Text(
              'Up to RM ${r.maxPricePerKg!.toStringAsFixed(2)} /kg',
              style: const TextStyle(
                fontSize: 14,
                color: TamuColors.textSecondary,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: TamuColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                mine ? 'You' : r.buyerName,
                style: const TextStyle(
                  fontSize: 14,
                  color: TamuColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _timeAgo(r.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: TamuColors.textSecondary,
                ),
              ),
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
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: TamuColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Accepted by ${r.acceptedByName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TamuColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (r.convertedOrderId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: TamuColors.info,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Became order #${r.convertedOrderId}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: TamuColors.info,
                        ),
                      ),
                    ),
                    // Only the two people in the order can open it.
                    if (mine || r.acceptedById == ApiService.currentUser?.id)
                      TextButton(
                        onPressed: _openOrders,
                        child: const Text('View order'),
                      ),
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
              if (r.myOffer != null && r.myOffer!.isOpen)
                _buildMyOffer(r, r.myOffer!)
              else
                ElevatedButton.icon(
                  onPressed: () => _sendOffer(r),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Send an offer'),
                ),
            ],
            if (mine && r.isOpen) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showOffers(r),
                icon: const Icon(Icons.local_offer_outlined),
                label: Text(
                  r.offerCount == 0
                      ? 'No offers yet'
                      : r.offerCount == 1
                      ? 'See 1 offer'
                      : 'See ${r.offerCount} offers',
                ),
              ),
              const SizedBox(height: 8),
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

  /// The farmer's own open offer, with a way to take it back.
  Widget _buildMyOffer(CropRequest r, RequestOffer offer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TamuColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your offer: RM ${offer.pricePerKg.toStringAsFixed(2)}/kg · '
            'total RM ${offer.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TamuColors.primary,
            ),
          ),
          const Text(
            'Waiting for the buyer to choose',
            style: TextStyle(fontSize: 13, color: TamuColors.textSecondary),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _withdrawOffer(r, offer),
              style: TextButton.styleFrom(foregroundColor: TamuColors.danger),
              child: const Text('Withdraw offer'),
            ),
          ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
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
            style: const TextStyle(
              fontSize: 14,
              color: TamuColors.textSecondary,
            ),
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
        const Icon(
          Icons.campaign_outlined,
          size: 56,
          color: TamuColors.textSecondary,
        ),
        const SizedBox(height: 12),
        const Text(
          'Cannot load requests',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          msg.replaceFirst('Exception: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: TamuColors.danger),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
      ],
    );
  }
}

/// What the farmer chose in the accept dialog.
/// productId == null means "accept without creating an order".
class _OfferDraft {
  final int productId;
  final double pricePerKg;
  final String? note;
  const _OfferDraft({
    required this.productId,
    required this.pricePerKg,
    this.note,
  });
}

/// FR6 bidding: the farmer picks a listing, sets a price per kg (the
/// listing's price by default) and can add a note for the buyer.
/// True when the listing and the request name the same crop: every word of
/// the shorter name appears in the longer one ("Bayam", "Sayur Bayam").
bool sameCrop(String a, String b) {
  Set<String> words(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toSet();
  final x = words(a), y = words(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x.length <= y.length ? y.containsAll(x) : x.containsAll(y);
}

class _OfferDialog extends StatefulWidget {
  final CropRequest request;
  final List<Product> listings;
  const _OfferDialog({required this.request, required this.listings});

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  Product? _listing;
  final _price = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.listings.isNotEmpty) _choose(widget.listings.first);
  }

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  void _choose(Product p) {
    _listing = p;
    _price.text = p.pricePerUnit.toStringAsFixed(2);
    _error = null;
  }

  void _submit() {
    final price = double.tryParse(_price.text.trim());
    final max = widget.request.maxPricePerKg;
    String? error;
    if (price == null || price <= 0) {
      error = 'Enter a price per kg, e.g. 4.50';
    } else if (max != null && price > max) {
      error = 'The buyer pays at most RM ${max.toStringAsFixed(2)} per kg.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      _OfferDraft(
        productId: _listing!.id,
        pricePerKg: price!,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final price = double.tryParse(_price.text.trim());
    return AlertDialog(
      title: Text('Offer to supply ${r.cropName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.buyerName} needs ${r.quantityKg} kg.',
              style: const TextStyle(fontSize: 15),
            ),
            if (r.maxPricePerKg != null)
              Text(
                'Up to RM ${r.maxPricePerKg!.toStringAsFixed(2)} /kg',
                style: const TextStyle(
                  fontSize: 13,
                  color: TamuColors.textSecondary,
                ),
              ),
            const SizedBox(height: 12),
            if (widget.listings.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'To send an offer, you need a ${r.cropName} listing on sale '
                  'today, sold by kg, with at least ${r.quantityKg} kg in '
                  'stock. Add or update one in My listings, then come back.',
                  style: const TextStyle(fontSize: 13),
                ),
              )
            else ...[
              const Text(
                'Supply it from:',
                style: TextStyle(fontSize: 14, color: TamuColors.textSecondary),
              ),
              const SizedBox(height: 6),
              for (final p in widget.listings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _choose(p)),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      backgroundColor: _listing == p
                          ? TamuColors.primary.withValues(alpha: 0.08)
                          : null,
                      side: BorderSide(
                        color: _listing == p
                            ? TamuColors.primary
                            : TamuColors.border,
                        width: _listing == p ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _listing == p
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: TamuColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'RM ${p.pricePerUnit.toStringAsFixed(2)}/kg  ·  '
                                '${p.stockQuantity} kg in stock',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: TamuColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: tr('Your price per kg (RM)'),
                  prefixText: 'RM ',
                  errorText: tr(_error),
                ),
              ),
              if (price != null && price > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Total for the buyer: RM '
                    '${(price * r.quantityKg).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TamuColors.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Note for the buyer (optional)'),
                  hintText: tr('e.g. Harvested this morning'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(fontSize: 16)),
        ),
        if (widget.listings.isNotEmpty)
          ElevatedButton(onPressed: _submit, child: const Text('Send offer')),
      ],
    );
  }
}

/// FR6 bidding: the buyer's list of offers on one request, cheapest
/// first. Returns the offer the buyer chooses.
class _OffersSheet extends StatelessWidget {
  final CropRequest request;
  const _OffersSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: FutureBuilder<List<RequestOffer>>(
          future: ApiService.fetchOffers(request.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Shimmer(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SkeletonCard(kind: SkeletonKind.offer),
                      SizedBox(height: 10),
                      SkeletonCard(kind: SkeletonKind.offer),
                    ],
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                ),
              );
            }
            final offers = (snapshot.data ?? [])
                .where((o) => o.isOpen)
                .toList();
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  'Offers for ${request.cropName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${request.quantityKg} kg needed',
                  style: const TextStyle(
                    fontSize: 14,
                    color: TamuColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (offers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No offers yet. Farmers will be notified about your '
                      'request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: TamuColors.textSecondary,
                      ),
                    ),
                  ),
                for (final o in offers)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TamuColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.farmerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'RM ${o.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: TamuColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${o.productName ?? request.cropName}  ·  RM '
                          '${o.pricePerKg.toStringAsFixed(2)}/kg',
                          style: const TextStyle(
                            fontSize: 13,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                        if (o.note != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"${o.note}"',
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(o),
                            child: const Text('Choose this offer'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
