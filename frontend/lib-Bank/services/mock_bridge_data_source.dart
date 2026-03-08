import 'dart:async';
import 'dart:math';
import '../models.dart';
import '../demo_data.dart';
import 'bridge_data_source.dart';

/// 開発・デモ用の Mock 実装。
/// ブロックチェーン側のロジックが確定したら、このクラスを実際の実装に差し替える。
///
/// 動作: [_tickInterval] 毎に新トランザクションをランダム追加し、KPIを更新して
/// [snapshots] にイベントを流す。
class MockBridgeDataSource implements BridgeDataSource {
  static const _tickInterval = Duration(seconds: 4);

  final _rng = Random();
  final _controller = StreamController<DashboardSnapshot>.broadcast();
  Timer? _timer;

  // 内部状態
  final List<BridgeTransaction> _txList = List.from(demoTransactions);
  double _totalInflow = 1_200_000_000;
  double _volume24h = 84_500_000;
  final List<double> _sparkline = List.from(demoSparkline);

  MockBridgeDataSource() {
    // 初回即時発行
    _emit();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }

  @override
  Stream<DashboardSnapshot> get snapshots => _controller.stream;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  // ---- 内部 ----

  void _tick() {
    _maybeAddTransaction();
    _maybeProgressTransaction();
    _updateKpis();
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    final active = _txList
        .where((t) => t.status == BridgeStatus.locked || t.status == BridgeStatus.syncing)
        .length;
    _controller.add(DashboardSnapshot(
      totalLiquidityInflow: _totalInflow,
      inflowSparkline: List.unmodifiable(_sparkline),
      activeBridgeTransactions: active,
      volume24h: _volume24h,
      recentTransactions: List.unmodifiable(_txList.take(20).toList()),
    ));
  }

  void _maybeAddTransaction() {
    if (_rng.nextDouble() > 0.6) return; // 確率 40% でスキップ
    final amount = (50000 + _rng.nextInt(20000000)).toDouble();
    final hash =
        '0x${_rng.nextInt(0xffff).toRadixString(16).padLeft(4, '0')}…${_rng.nextInt(0xffff).toRadixString(16).padLeft(4, '0')}';
    _txList.insert(
      0,
      BridgeTransaction(
        timestamp: DateTime.now(),
        publicTxHash: hash,
        amountUsdt: amount,
        status: BridgeStatus.locked,
      ),
    );
    if (_txList.length > 50) _txList.removeLast();
  }

  void _maybeProgressTransaction() {
    // locked → syncing or syncing → credited をランダムに進める
    for (var i = 0; i < _txList.length; i++) {
      if (_rng.nextDouble() > 0.4) continue;
      final tx = _txList[i];
      BridgeStatus? next;
      if (tx.status == BridgeStatus.locked) next = BridgeStatus.syncing;
      if (tx.status == BridgeStatus.syncing) next = BridgeStatus.credited;
      if (next != null) {
        _txList[i] = BridgeTransaction(
          timestamp: tx.timestamp,
          publicTxHash: tx.publicTxHash,
          amountUsdt: tx.amountUsdt,
          status: next,
        );
      }
    }
  }

  void _updateKpis() {
    final delta = (500000 + _rng.nextInt(5000000)).toDouble();
    _totalInflow += delta;
    _volume24h += delta * 0.07 * (_rng.nextBool() ? 1 : -1);
    _volume24h = _volume24h.clamp(1_000_000, 200_000_000);
    // スパークライン: 最古の点を捨て最新を追加
    _sparkline.removeAt(0);
    _sparkline.add(_totalInflow / 1e9);
  }
}
