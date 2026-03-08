import 'package:flutter/material.dart';
import '../theme.dart';
import '../../shared/demo_data.dart';
import '../services/bridge_data_source.dart';
import 'kpi_cards.dart';
import 'bridge_monitor.dart';
import 'st_allocation.dart';
import 'sidebar.dart';

class BankDashboardPage extends StatefulWidget {
  final BridgeDataSource dataSource;
  const BankDashboardPage({super.key, required this.dataSource});

  @override
  State<BankDashboardPage> createState() => _BankDashboardPageState();
}

class _BankDashboardPageState extends State<BankDashboardPage> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildBankTheme(),
      child: Scaffold(
        body: Row(
          children: [
            AppSidebar(selectedIndex: _navIndex, onSelect: (i) => setState(() => _navIndex = i)),
            const VerticalDivider(width: 1, thickness: 1, color: BankColors.border),
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
                              Expanded(flex: 3, child: BridgeMonitor(transactions: data?.recentTransactions ?? [])),
                              const SizedBox(width: 24),
                              Expanded(flex: 1, child: StMarketAllocation(allocations: demoAllocations)),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Treasury Gateway',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 22)),
            const SizedBox(height: 4),
            Text('USDT → Security Token Bridge  |  Liquidity Dashboard',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: BankColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: BankColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: BankColors.textSecondary),
              const SizedBox(width: 6),
              Text('Last 24 hours', style: bankMono(size: 12, color: BankColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(DashboardSnapshot? data) {
    final inflowStr = data == null ? '\$0' : '\$${_fmt(data.totalLiquidityInflow)}';
    final activeStr = data == null ? '0' : '${data.activeBridgeTransactions}';
    final volumeStr = data == null ? '\$0' : '\$${_fmt(data.volume24h)}';
    final sparkline = data?.inflowSparkline ?? List.filled(12, 0.0);

    return Row(
      children: [
        Expanded(
          child: KpiCard(
            title: 'Total Liquidity Inflow',
            value: inflowStr,
            subtitle: 'USDT bridged all-time',
            icon: Icons.trending_up_rounded,
            iconColor: BankColors.emerald,
            trailing: SparklineWidget(data: sparkline),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KpiCard(title: 'Active Bridge Txns', value: activeStr, subtitle: 'Pending settlement', icon: Icons.sync_rounded, iconColor: BankColors.accent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KpiCard(title: '24h Bridge Volume', value: volumeStr, subtitle: 'Daily throughput', icon: Icons.bar_chart_rounded, iconColor: BankColors.amber),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: KpiCard(
            title: 'Network Status',
            value: 'Operational',
            icon: Icons.cloud_done_rounded,
            iconColor: BankColors.emerald,
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

  String _fmt(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
