import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/crop_photo.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Marketplace oversight: every listing, with Hide / Show for listings
/// that break the rules (Table 1.2, Admin CRUD on product listings).
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _search = TextEditingController();
  String? _status;
  List<AdminProduct> _items = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await AdminApi.products(
        search: _search.text.trim(),
        status: _status,
      );
      if (mounted) {
        setState(() {
          _items = list;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _reload() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _toggle(AdminProduct p) async {
    final hide = !p.adminHidden;
    if (hide) {
      final yes = await confirmAction(
        context,
        title: 'Hide ${p.name}?',
        message:
            'Buyers will no longer see or order this listing. '
            '${p.farmerName} gets a notification. You can show it again '
            'at any time.',
        action: 'Hide',
        danger: true,
      );
      if (!yes) return;
    }
    try {
      await AdminApi.setProductHidden(p.id, hide);
      if (!mounted) return;
      showAdminSnack(
        context,
        hide ? '${p.name} is hidden.' : '${p.name} is visible again.',
      );
      _load();
    } catch (e) {
      if (mounted) showAdminSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Products',
      subtitle: 'Every crop listing on the marketplace',
      onRefresh: _load,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SearchBox(
              hint: 'Search crop, farmer or farm',
              controller: _search,
              onSubmitted: (_) => _reload(),
            ),
            FilterChips(
              options: const {
                null: 'All',
                'live': 'Live',
                'hidden': 'Hidden',
                'expired': 'Expired',
              },
              selected: _status,
              onChanged: (v) {
                _status = v;
                _reload();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminPanel(
          child: LoadState(
            loading: _loading,
            error: _error,
            empty: _items.isEmpty,
            emptyText: 'No listings match.',
            onRetry: _reload,
            child: AdminTable(
              columns: const [
                'Crop',
                'Farm',
                'Price',
                'Stock',
                'Orders',
                'Status',
                'Action',
              ],
              widths: const [2.4, 2, 1.3, 1.2, .8, 1.4, 1],
              rows: [
                for (final p in _items)
                  [
                    Row(
                      children: [
                        CropPhoto(
                          photoUrl: p.photoUrl,
                          category: p.category,
                          width: 40,
                          height: 40,
                          radius: 8,
                          emojiSize: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: CellText(p.name, sub: p.category)),
                      ],
                    ),
                    CellText(
                      p.farmName ?? p.farmerName,
                      sub: p.farmName == null ? null : p.farmerName,
                    ),
                    Text(
                      '${money(p.pricePerUnit)} / ${p.unit}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '${p.stockQuantity} ${p.unit}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text('${p.orders}', style: const TextStyle(fontSize: 14)),
                    StatusPill.forStatus(p.status),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: p.adminHidden
                            ? TamuColors.primary
                            : TamuColors.danger,
                      ),
                      onPressed: () => _toggle(p),
                      child: Text(p.adminHidden ? 'Show' : 'Hide'),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
