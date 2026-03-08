import 'dart:async';
import 'dart:math';
import '../../shared/models.dart';
import '../../shared/payment_event_bus.dart';
import 'bridge_data_source.dart';

/// イベント駆動型 BridgeDataSource。
/// PaymentEventBus から決済指令を受信し、トランザクションを生成 → 進行させる。
/// ダミーのタイマー自動生成は一切行わない。
class EventDrivenBridgeSource implements BridgeDataSource {
  final _rng = Random();
  final _controller = StreamController<DashboardSnapshot>.broadcast();
  StreamSubscription<PaymentInstruction>? _sub;
  Timer? _progressTimer;

  // ---- 内部状態 ----
  final List<BridgeTransaction> _txList = [];
  double _totalInflow = 0;
  double _volume24h = 0;
  final List<double> _sparkline = List.filled(12, 0.0);

  EventDrivenBridgeSource() {
    _sub = PaymentEventBus.instance.payments.listen(_onPaymentReceived);
    // トランザクションの進行のみを行う軽量タイマー（新規生成は行わない）
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_progressTransactions()) _emit();
    });
    _emit();
  }

  @override
  Stream<DashboardSnapshot> get snapshots => _controller.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _progressTimer?.cancel();
    _controller.close();
  }

  // ---- エンドユーザーからの決済指令を処理 ----

  void _onPaymentReceived(PaymentInstruction instruction) {
    final hash =
        '0x${_rng.nextInt(0xffff).toRadixString(16).padLeft(4, '0')}…${_rng.nextInt(0xffff).toRadixString(16).padLeft(4, '0')}';

    _txList.insert(
      0,
      BridgeTransaction(
        timestamp: instruction.timestamp,
        publicTxHash: hash,
        amountUsdt: instruction.amountUsdt,
        status: BridgeStatus.locked,
      ),
    );
    if (_txList.length > 50) _txList.removeLast();

    // KPI 更新
    _totalInflow += instruction.amountUsdt;
    _volume24h += instruction.amountUsdt;

    // スパークライン更新
    _sparkline.removeAt(0);
    _sparkline.add(_totalInflow / 1e6);

    _emit();
  }

  // ---- トランザクション進行 (locked → syncing → credited) ----

  bool _progressTransactions() {
    bool changed = false;
    for (var i = 0; i < _txList.length; i++) {
      final tx = _txList[i];
      BridgeStatus? next;
      if (tx.status == BridgeStatus.locked) {
        next = BridgeStatus.syncing;
      } else if (tx.status == BridgeStatus.syncing) {
        next = BridgeStatus.credited;
      }
      if (next != null) {
        _txList[i] = tx.copyWith(status: next);
        changed = true;
        break; // 1サイクルにつき1つだけ進行（デモで段階的に見せるため）
      }
    }
    return changed;
  }

  // ---- スナップショット発行 ----

  void _emit() {
    if (_controller.isClosed) return;
    final active = _txList
        .where((t) => t.status != BridgeStatus.credited)
        .length;
    _controller.add(
      DashboardSnapshot(
        totalLiquidityInflow: _totalInflow,
        inflowSparkline: List.unmodifiable(_sparkline),
        activeBridgeTransactions: active,
        volume24h: _volume24h,
        recentTransactions: List.unmodifiable(_txList.take(20).toList()),
      ),
    );
  }
}
