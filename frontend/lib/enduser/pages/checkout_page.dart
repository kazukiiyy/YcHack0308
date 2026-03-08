import 'package:flutter/material.dart';
import '../../shared/models.dart';
import '../../shared/payment_event_bus.dart';
import '../theme.dart';

class CheckoutSheet extends StatefulWidget {
  final StProduct product;
  const CheckoutSheet({super.key, required this.product});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

enum _CheckoutState { input, processing, complete }

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _amountController = TextEditingController();
  _CheckoutState _state = _CheckoutState.input;
  int _quantity = 1;

  double get _totalAmount => widget.product.priceUsdt * _quantity;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: EndUserColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          if (_state == _CheckoutState.input) _buildInputView(),
          if (_state == _CheckoutState.processing) _buildProcessingView(),
          if (_state == _CheckoutState.complete) _buildCompleteView(),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 商品情報
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: EndUserColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  widget.product.imageIcon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: EndUserColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.product.category,
                    style: const TextStyle(
                      fontSize: 13,
                      color: EndUserColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 数量選択
        Text(
          'Quantity',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: EndUserColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: EndUserColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded),
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: endUserMono(
                      size: 18,
                      weight: FontWeight.w700,
                      color: EndUserColors.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 決済方法
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EndUserColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EndUserColors.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: EndUserColors.emerald,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.currency_exchange,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USDT (Tether)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: EndUserColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Public chain wallet',
                      style: TextStyle(
                        fontSize: 12,
                        color: EndUserColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle_rounded,
                color: EndUserColors.accent,
                size: 22,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 合計
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EndUserColors.textPrimary,
              ),
            ),
            Text(
              '\$${_fmtAmount(_totalAmount)} USDT',
              style: endUserMono(
                size: 20,
                weight: FontWeight.w700,
                color: EndUserColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 確定ボタン
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _confirmPayment,
            style: FilledButton.styleFrom(
              backgroundColor: EndUserColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Confirm Payment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 20),
            Text(
              'Processing USDT transfer…',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EndUserColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Locking on public chain',
              style: TextStyle(
                fontSize: 13,
                color: EndUserColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteView() {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: EndUserColors.emerald,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Submitted',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: EndUserColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${_fmtAmount(_totalAmount)} USDT → ${widget.product.name}',
              style: const TextStyle(
                fontSize: 13,
                color: EndUserColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your transaction is being bridged to the private chain.',
              style: TextStyle(
                fontSize: 12,
                color: EndUserColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPayment() {
    setState(() => _state = _CheckoutState.processing);

    // PaymentEventBus に決済指令を送信
    PaymentEventBus.instance.submitPayment(
      PaymentInstruction(
        productName: widget.product.name,
        amountUsdt: _totalAmount,
        userWalletAddress: '0x742d…Fa4e', // デモ用ダミーアドレス
      ),
    );

    // 処理完了を演出（実際はブリッジ応答を待つ）
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _state = _CheckoutState.complete);
    });
  }

  String _fmtAmount(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(v % 1e3 == 0 ? 0 : 1)}K';
    return v.toStringAsFixed(0);
  }
}
