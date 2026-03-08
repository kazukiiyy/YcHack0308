import '../../shared/models.dart';

/// ダッシュボードのKPIスナップショット。
class DashboardSnapshot {
  final double totalLiquidityInflow;
  final List<double> inflowSparkline;
  final int activeBridgeTransactions;
  final double volume24h;
  final List<BridgeTransaction> recentTransactions;

  const DashboardSnapshot({
    required this.totalLiquidityInflow,
    required this.inflowSparkline,
    required this.activeBridgeTransactions,
    required this.volume24h,
    required this.recentTransactions,
  });
}

/// ブリッジデータソースの抽象インターフェース。
abstract class BridgeDataSource {
  Stream<DashboardSnapshot> get snapshots;
  void dispose();
}
