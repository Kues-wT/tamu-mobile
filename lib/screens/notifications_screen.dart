import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import '../theme.dart';
import '../api_service.dart';
import 'orders_screen.dart' as orders;
import 'requests_screen.dart' as requests;

/// FR8 - Notification Management.
/// Alerts are generated server-side when orders change state or crop
/// requests are posted / accepted.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  String _filter = 'all';

  static const _filters = ['all', 'order', 'request', 'system'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ApiService.fetchNotifications(
      type: _filter == 'all' ? null : _filter,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      _snack('All notifications marked as read', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  /// Marks the alert read, then jumps to whatever it is about.
  /// ref_type tells us which screen: "order" or "request".
  Future<void> _tap(AppNotification n) async {
    if (!n.isRead) {
      try {
        await ApiService.markNotificationRead(n.id);
      } catch (_) {
        // Reading a notification is not critical; ignore failures.
      }
    }
    if (!mounted) return;
    await _open(n);
    if (mounted) await _refresh();
  }

  Future<void> _open(AppNotification n) async {
    final target = switch (n.refType) {
      'order' => const orders.OrdersScreen(),
      'request' => const requests.RequestsScreen(),
      _ => null,
    };
    if (target == null) {
      // System messages have nothing to open; just mark as read.
      if (mounted) await _refresh();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  String _actionLabel(AppNotification n) => switch (n.refType) {
        'order' => 'VIEW ORDER',
        'request' => 'VIEW REQUEST',
        _ => '',
      };

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content:
            Text(msg, style: const TextStyle(fontSize: 16, color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<AppNotification>>(
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
                          padding:
                              const EdgeInsets.all(TamuSizes.pagePadding),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _buildTile(items[i]),
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

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final f = _filters[i];
            final selected = _filter == f;
            return ChoiceChip(
              label: Text(
                f[0].toUpperCase() + f.substring(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : TamuColors.textPrimary,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: TamuColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                  color: selected ? TamuColors.primary : TamuColors.border),
              onSelected: (_) => setState(() {
                _filter = f;
                _load();
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTile(AppNotification n) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;

    switch (n.type) {
      case 'order':
        bg = TamuColors.lightGreen;
        fg = TamuColors.primary;
        icon = Icons.receipt_long_outlined;
      case 'request':
        bg = const Color(0xFFE3F2FD);
        fg = TamuColors.info;
        icon = Icons.campaign_outlined;
      default:
        bg = const Color(0xFFEEEEEE);
        fg = TamuColors.textSecondary;
        icon = Icons.info_outline;
    }

    return InkWell(
      onTap: () => _tap(n),
      borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      child: Container(
        margin: const EdgeInsets.only(bottom: TamuSizes.gap),
        padding: const EdgeInsets.all(TamuSizes.cardPadding),
        decoration: BoxDecoration(
          color: n.isRead ? TamuColors.surface : const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
          border: Border.all(
            color: n.isRead ? TamuColors.border : TamuColors.secondary,
            width: n.isRead ? 1 : 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: n.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                            )),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: TamuColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n.message, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(_timeAgo(n.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: TamuColors.textSecondary)),
                      const Spacer(),
                      if (n.refType == 'order' || n.refType == 'request')
                        TextButton.icon(
                          onPressed: () => _tap(n),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 36),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: fg,
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 15),
                          label: Text(_actionLabel(n),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  Widget _buildEmpty() {
    return ListView(
      children: const [
        SizedBox(height: 90),
        Center(child: Text('🔔', style: TextStyle(fontSize: 46))),
        SizedBox(height: 12),
        Center(
          child: Text('No notifications yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: 4),
        Center(
          child: Text('Order and request updates will appear here.',
              style: TextStyle(fontSize: 14, color: TamuColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.notifications_off_outlined,
            size: 56, color: TamuColors.textSecondary),
        const SizedBox(height: 12),
        const Text('Cannot load notifications',
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
