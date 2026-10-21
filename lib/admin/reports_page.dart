import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Figure 4.30 - Platform Reports (week / month / year).
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _period = 'month';
  PlatformReport? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi.report(_period);
      if (mounted) {
        setState(() {
          _data = d;
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

  static const _periodNote = {
    'week': 'Last 7 days',
    'month': 'This month',
    'year': 'Last 12 months',
  };

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Platform Reports',
      subtitle: '${_periodNote[_period]} · revenue counts completed orders',
      onRefresh: _load,
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'week', label: Text('Week')),
          ButtonSegment(value: 'month', label: Text('Month')),
          ButtonSegment(value: 'year', label: Text('Year')),
        ],
        selected: {_period},
        showSelectedIcon: false,
        onSelectionChanged: (s) {
          _period = s.first;
          _load();
        },
      ),
      children: [
        LoadState(
          loading: _loading && _data == null,
          error: _error,
          empty: false,
          emptyText: '',
          onRetry: _load,
          child: _data == null ? const SizedBox() : _body(_data!),
        ),
      ],
    );
  }

  Widget _body(PlatformReport r) {
    final farms = AdminPanel(
      title: 'Top Farms',
      child: _rankTable('Farm', 'Orders', [
        for (final f in r.topFarms) (f.farmName, '${f.orders}'),
      ]),
    );
    final crops = AdminPanel(
      title: 'Top Crops',
      child: _rankTable('Crop', 'Sold', [
        for (final c in r.topCrops)
          (c.name, formatUnitQuantity(c.quantity, c.unit)),
      ]),
    );

    return Opacity(
      opacity: _loading ? .5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatGrid(
            cards: [
              StatCard(
                label: 'Total Orders',
                value: '${r.totalOrders}',
                note: '${r.completedOrders} completed',
              ),
              StatCard(label: 'Revenue', value: money(r.revenue)),
              StatCard(
                label: 'New Farmers',
                value: '${r.newFarmers}',
                note: '${r.newBuyers} new buyers',
              ),
              StatCard(
                label: 'Active Buyers',
                value: '${r.activeBuyers}',
                note: 'Placed at least one order',
              ),
            ],
          ),
          const SizedBox(height: 20),
          AdminPanel(
            title: r.period == 'week' ? 'Daily Orders' : 'Monthly Orders',
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: _BarChart(buckets: r.chart),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [farms, const SizedBox(height: 20), crops],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: farms),
                  const SizedBox(width: 20),
                  Expanded(child: crops),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _rankTable(String a, String b, List<(String, String)> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No orders in this period.',
          style: TextStyle(color: TamuColors.textSecondary),
        ),
      );
    }
    TextStyle head = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: .4,
      color: TamuColors.textSecondary,
    );
    Widget line(Widget left, Widget right, {bool header = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF7F8F6) : null,
        border: const Border(bottom: BorderSide(color: TamuColors.line)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: left),
          Expanded(flex: 1, child: right),
        ],
      ),
    );
    return Column(
      children: [
        line(
          Text(a.toUpperCase(), style: head),
          Text(b.toUpperCase(), style: head),
          header: true,
        ),
        for (var i = 0; i < rows.length; i++)
          line(
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: TamuColors.lightGreen,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TamuColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            Text(
              rows[i].$2,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// Simple bar chart: one bar per bucket, the order count above it.
class _BarChart extends StatelessWidget {
  final List<ReportBucket> buckets;
  const _BarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxOrders = buckets.fold<int>(
      0,
      (m, b) => b.orders > m ? b.orders : m,
    );
    const chartHeight = 200.0;
    return SizedBox(
      height: chartHeight + 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in buckets)
            Expanded(
              child: Tooltip(
                message: '${b.orders} orders · ${money(b.revenue)} revenue',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${b.orders}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: maxOrders == 0
                            ? 2
                            : (b.orders / maxOrders * chartHeight).clamp(
                                2,
                                chartHeight,
                              ),
                        constraints: const BoxConstraints(maxWidth: 56),
                        decoration: BoxDecoration(
                          color: b.orders == 0
                              ? TamuColors.line
                              : TamuColors.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.label,
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
              ),
            ),
        ],
      ),
    );
  }
}
