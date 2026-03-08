import 'dart:async';

/// エンドユーザーアプリから銀行システムへの決済指令。
class PaymentInstruction {
  final String productName;
  final double amountUsdt;
  final String userWalletAddress;
  final DateTime timestamp;

  PaymentInstruction({
    required this.productName,
    required this.amountUsdt,
    required this.userWalletAddress,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// エンドユーザーアプリと銀行システム間のインメモリイベントバス。
/// 同一プロセス内でリアルタイム通信を行う。
/// ブロックチェーン実装が確定したら、HTTP/WebSocket に差し替え可能。
class PaymentEventBus {
  static final instance = PaymentEventBus._();
  PaymentEventBus._();

  final _controller = StreamController<PaymentInstruction>.broadcast();

  /// 銀行システムが購読する Stream。
  Stream<PaymentInstruction> get payments => _controller.stream;

  /// エンドユーザーアプリが決済指令を発行する。
  void submitPayment(PaymentInstruction instruction) {
    _controller.add(instruction);
  }

  void dispose() => _controller.close();
}
