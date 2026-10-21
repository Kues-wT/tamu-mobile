import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../theme.dart';
import 'admin_widgets.dart';
import 'announcements_page.dart';
import 'dashboard_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'reports_page.dart';
import 'users_page.dart';

/// FR1 Admin - the web admin panel (Figure 4.28 layout): a sidebar with
/// the sections on wide screens, a drawer on phones.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

enum AdminSection { dashboard, users, products, orders, reports, announcements }

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.dashboard;
  int _unread = 0;
  Timer? _poll;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _items = {
    AdminSection.dashboard: (Icons.dashboard_outlined, 'Dashboard'),
    AdminSection.users: (Icons.people_outline, 'Users'),
    AdminSection.products: (Icons.inventory_2_outlined, 'Products'),
    AdminSection.orders: (Icons.receipt_long_outlined, 'Orders'),
    AdminSection.reports: (Icons.bar_chart, 'Reports'),
    AdminSection.announcements: (Icons.campaign_outlined, 'Announcements'),
  };

  @override
  void initState() {
    super.initState();
    _loadUnread();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnread());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final n = await ApiService.fetchUnreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (e) {
      if (errorText(e).contains('401')) _toLogin();
    }
  }

  void _go(AdminSection s) {
    setState(() => _section = s);
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
  }

  void _toLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    final yes = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again.',
      action: 'Sign out',
    );
    if (!yes) return;
    await ApiService.logout();
    _toLogin();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _loadUnread();
  }

  Widget _page() => switch (_section) {
    AdminSection.dashboard => DashboardPage(onOpen: _go),
    AdminSection.users => const UsersPage(),
    AdminSection.products => const ProductsPage(),
    AdminSection.orders => const OrdersPage(),
    AdminSection.reports => const ReportsPage(),
    AdminSection.announcements => const AnnouncementsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final page = KeyedSubtree(key: ValueKey(_section), child: _page());

    if (wide) {
      return Scaffold(
        backgroundColor: TamuColors.warm,
        body: Row(
          children: [
            SizedBox(width: 260, child: _sidebar()),
            const VerticalDivider(width: 1, color: TamuColors.line),
            Expanded(child: page),
          ],
        ),
      );
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: TamuColors.warm,
      appBar: AppBar(
        title: Text(_items[_section]!.$2),
        actions: [_bell(Colors.white)],
      ),
      drawer: Drawer(child: _sidebar()),
      body: page,
    );
  }

  Widget _bell(Color color) => IconButton(
    tooltip: 'Notifications',
    onPressed: _openNotifications,
    icon: Badge(
      isLabelVisible: _unread > 0,
      label: Text('$_unread'),
      child: Icon(Icons.notifications_none, color: color),
    ),
  );

  Widget _sidebar() {
    final user = ApiService.currentUser;
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: TamuColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'TAMU',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TamuColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const StatusPill(
                    'Admin',
                    fg: TamuColors.greyBadgeText,
                    bg: TamuColors.greyBadgeBg,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: TamuColors.line),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final e in _items.entries) _navItem(e.key, e.value),
                ],
              ),
            ),
            const Divider(height: 1, color: TamuColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: TamuColors.primary,
                    foregroundColor: Colors.white,
                    child: Text(
                      (user?.fullName.isNotEmpty ?? false)
                          ? user!.fullName[0].toUpperCase()
                          : 'A',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Admin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _bell(TamuColors.textSecondary),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout,
                      color: TamuColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(AdminSection s, (IconData, String) item) {
    final selected = s == _section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? TamuColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _go(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.$1,
                  size: 20,
                  color: selected ? Colors.white : TamuColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Colors.white : TamuColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
