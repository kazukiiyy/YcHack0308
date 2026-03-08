import 'package:flutter/material.dart';
import '../theme.dart';
import '../demo_data.dart';
import '../services/bridge_data_source.dart';
import 'kpi_cards.dart';
import 'bridge_monitor.dart';
import 'st_allocation.dart';
import 'sidebar.dart';

class DashboardPage extends StatefulWidget {
  /// ブリッジデータソース。MockBridgeDataSource か本番実装を外から注入する。
  final BridgeDataSource dataSource;

  const DashboardPage({super.key, required this.dataSource});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: _navIndex,
            onSelect: (i) => setState(() => _navIndex = i),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: StreamBuilder<DashboardSnapshot>(
              stream: widget.dataSource.snapshots,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildKpiRow(data),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: BridgeMonitor(
                                transactions: data?.recentTransactions ?? [],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 1,
                              child: StMarketAllocation(allocations: demoAllocations),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Treasury Gateway',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'USDT → Security Token Bridge  |  Liquidity Dashboard',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Last 24 hours', style: monoStyle(size: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(DashboardSnapshot? data) {
    final inflowStr = data == null ? '---' : _fmtCompact(data.totalLiquidityInflow);
    final activeStr = data == null ? '---' : '${data.activeBridgeTransactions}';
    final volumeStr = data == null ? '---' : _fmtCompact(data.volume24h);
    final sparkline = data?.inflowSparkline ?? demoSparkline;

    return Row(
      children: [
        Expanded(
          child: KpiCard(
            title: 'Total Liquidity Inflow',
            value: '\$$inflowStr',
            subtitle: 'USDT bridged all-time',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.emerald,
            trailing: SparklineWidget(data: sparkline),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KpiCard(
            title: 'Active Bridge Transactions',
            value: activeStr,
            subtitle: 'Pending settlement',
            icon: Icons.sync_rounded,
            iconColor: AppColors.accent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KpiCard(
            title: '24h Bridge Volume',
            value: '\$$volumeStr',
            subtitle: '+12.3% from yesterday',
            icon: Icons.bar_chart_rounded,
            iconColor: AppColors.amber,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KpiCard(
            title: 'Network Status',
            value: 'Operational',
            icon: Icons.cloud_done_rounded,
            iconColor: AppColors.emerald,
            trailing: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NetworkStatusIndicator(label: 'Public Node (Base)', isOnline: true),
                SizedBox(height: 6),
                NetworkStatusIndicator(label: 'Private Ledger (Progmat)', isOnline: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtCompact(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
