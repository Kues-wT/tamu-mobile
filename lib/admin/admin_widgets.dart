import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared building blocks for the admin panel (Figures 4.28 - 4.30).

String money(double v) {
  final whole = v.truncate().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  final cents = ((v - v.truncate()) * 100).round().toString().padLeft(2, '0');
  return 'RM $whole.$cents';
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return shortDate(t);
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

void showAdminSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? TamuColors.danger : TamuColors.primary,
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Text(message, style: const TextStyle(fontSize: 15)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? TamuColors.danger : TamuColors.primary,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Page frame: big title, grey subtitle, optional actions on the right.
class AdminPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  const AdminPage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final list = ListView(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 40 : 16,
        vertical: wide ? 32 : 18,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: wide ? 30 : 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: TamuColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// White rounded card with an optional header row.
class AdminPanel extends StatelessWidget {
  final String? title;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AdminPanel({
    super.key,
    this.title,
    this.action,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TamuColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: TamuColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? note;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TamuColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: TamuColors.textSecondary,
                  ),
                ),
              ),
              if (icon != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: TamuColors.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: TamuColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(
                fontSize: 13,
                color: TamuColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays stat cards out 4 / 2 / 1 per row depending on the width.
class StatGrid extends StatelessWidget {
  final List<Widget> cards;
  const StatGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 480 ? 2 : 1);
        const gap = 16.0;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;

  const StatusPill(this.text, {super.key, required this.fg, required this.bg});

  factory StatusPill.forStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'live':
      case 'completed':
        return StatusPill(
          _label(status),
          fg: TamuColors.primary,
          bg: TamuColors.lightGreen,
        );
      case 'pending':
        return StatusPill(
          _label(status),
          fg: TamuColors.amber,
          bg: TamuColors.amberBg,
        );
      case 'confirmed':
        return StatusPill(
          _label(status),
          fg: TamuColors.info,
          bg: const Color(0xFFE3F2FD),
        );
      case 'suspended':
      case 'hidden':
      case 'cancelled':
        return StatusPill(
          _label(status),
          fg: TamuColors.danger,
          bg: const Color(0xFFFFEBEE),
        );
      default:
        return StatusPill(
          _label(status),
          fg: TamuColors.greyBadgeText,
          bg: TamuColors.greyBadgeBg,
        );
    }
  }

  static String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Segmented filter chips, e.g. All / Farmer / Buyer / Admin.
class FilterChips extends StatelessWidget {
  final Map<String?, String> options; // value -> label
  final String? selected;
  final ValueChanged<String?> onChanged;

  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: selected == e.key,
            onSelected: (_) => onChanged(e.key),
            showCheckmark: false,
            selectedColor: TamuColors.primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: TamuColors.line),
            labelStyle: TextStyle(
              fontSize: 14,
              color: selected == e.key ? Colors.white : TamuColors.textPrimary,
            ),
          ),
      ],
    );
  }
}

class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onSubmitted;
  final TextEditingController controller;

  const SearchBox({
    super.key,
    required this.hint,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              controller.clear();
              onSubmitted('');
            },
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

/// Loading / error / empty states shared by every admin list.
class LoadState extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool empty;
  final String emptyText;
  final VoidCallback onRetry;
  final Widget child;

  const LoadState({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.emptyText,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 36, color: TamuColors.danger),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (empty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            emptyText,
            style: const TextStyle(color: TamuColors.textSecondary),
          ),
        ),
      );
    }
    return child;
  }
}

/// A plain table that scrolls sideways on narrow screens.
class AdminTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final List<double> widths; // flex weights

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.widths,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const minWidth = 820.0;
        final width = c.maxWidth < minWidth ? minWidth : c.maxWidth;
        Widget row(List<Widget> cells, {bool header = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: header ? const Color(0xFFF7F8F6) : null,
            border: const Border(bottom: BorderSide(color: TamuColors.line)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < cells.length; i++)
                Expanded(
                  flex: (widths[i] * 10).round(),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: cells[i],
                  ),
                ),
            ],
          ),
        );
        final table = SizedBox(
          width: width,
          child: Column(
            children: [
              row([
                for (final col in columns)
                  Text(
                    col.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .4,
                      color: TamuColors.textSecondary,
                    ),
                  ),
              ], header: true),
              for (final r in rows) row(r),
            ],
          ),
        );
        if (width == c.maxWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        );
      },
    );
  }
}

/// Two-line cell: bold main text and a grey line under it.
class CellText extends StatelessWidget {
  final String main;
  final String? sub;
  const CellText(this.main, {super.key, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            main,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          if (sub != null && sub!.isNotEmpty)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: TamuColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
