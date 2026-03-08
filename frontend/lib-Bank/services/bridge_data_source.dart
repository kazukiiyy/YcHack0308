import '../models.dart';

/// ダッシュボードのKPIスナップショット。
/// ブロックチェーン側が確定したら、このクラスのフィールドをRPC/イベントで埋める。
class DashboardSnapshot {
  /// 累計 USDT 流入額（単位: USDT）
  final double totalLiquidityInflow;

  /// スパークライン用の過去N点の流入量（表示用正規化済みでなくてOK）
  final List<double> inflowSparkline;

  /// ブリッジ処理中（Locked or Syncing）のトランザクション数
  final int activeBridgeTransactions;

  /// 過去24時間のブリッジ総量（単位: USDT）
  final double volume24h;

  /// 直近トランザクション一覧（最新順）
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
///
/// 実装例:
///   - [MockBridgeDataSource]  : 開発中のデモ用タイマーベース実装
///   - QuorumRpcBridgeDataSource (TODO): Quorum RPC / イベントリスナー実装
///   - WebSocketBridgeDataSource (TODO): WebSocket ベース実装
abstract class BridgeDataSource {
  /// ダッシュボード全体のスナップショット Stream。
  /// 新しいブロック確定や一定周期でイベントを発行する。
  Stream<DashboardSnapshot> get snapshots;

  /// リソースを解放する。[dispose] 後は [snapshots] を購読しないこと。
  void dispose();
}
