import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/models.dart';
import '../theme.dart';

class BridgeMonitor extends StatelessWidget {
  final List<BridgeTransaction> transactions;

  const BridgeMonitor({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: BankColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Real-time Bridge Monitor',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: BankColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _LiveBadge(),
              ],
            ),
            const SizedBox(height: 16),
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(
                        'Waiting for bridge transactions…',
                        style: bankMono(
                          size: 13,
                          color: BankColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _buildRow(context, transactions[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: BankColors.textSecondary,
      letterSpacing: 0.5,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text('TIMESTAMP', style: style)),
          SizedBox(width: 140, child: Text('TX HASH', style: style)),
          SizedBox(width: 140, child: Text('AMOUNT (USDT)', style: style)),
          Expanded(child: Text('STATUS', style: style)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, BridgeTransaction tx) {
    final timeStr = DateFormat('HH:mm:ss').format(tx.timestamp);
    final amountStr = _formatAmount(tx.amountUsdt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              timeStr,
              style: bankMono(size: 12, color: BankColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              tx.publicTxHash,
              style: bankMono(size: 12, color: BankColors.accent),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              amountStr,
              style: bankMono(size: 12, weight: FontWeight.w600),
            ),
          ),
          Expanded(child: _BridgeStatusIndicator(status: tx.status)),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '\$${(amount / 1000).toStringAsFixed(0)}K';
    return '\$${amount.toStringAsFixed(0)}';
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BankColors.emerald.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: BankColors.emerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: BankColors.emerald,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: bankMono(
              size: 10,
              color: BankColors.emerald,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BridgeStatusIndicator extends StatelessWidget {
  final BridgeStatus status;
  const _BridgeStatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final int activeStep;
    switch (status) {
      case BridgeStatus.locked:
        activeStep = 0;
      case BridgeStatus.syncing:
        activeStep = 1;
      case BridgeStatus.credited:
        activeStep = 2;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepChip('Locked', 0, activeStep),
        _connector(activeStep > 0),
        _stepChip('Syncing', 1, activeStep),
        _connector(activeStep > 1),
        _stepChip('Credited', 2, activeStep),
      ],
    );
  }

  Widget _stepChip(String label, int step, int activeStep) {
    final bool isActive = step <= activeStep;
    final bool isCurrent = step == activeStep;
    Color bg, fg;
    if (isCurrent && step == 2) {
      bg = BankColors.emerald.withValues(alpha: 0.15);
      fg = BankColors.emerald;
    } else if (isCurrent) {
      bg = BankColors.accent.withValues(alpha: 0.15);
      fg = BankColors.accent;
    } else if (isActive) {
      bg = BankColors.surfaceVariant;
      fg = BankColors.textSecondary;
    } else {
      bg = Colors.transparent;
      fg = BankColors.textSecondary.withValues(alpha: 0.4);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: isCurrent ? Border.all(color: fg.withValues(alpha: 0.3)) : null,
      ),
      child: Text(
        label,
        style: bankMono(
          size: 10,
          color: fg,
          weight: isCurrent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _connector(bool active) {
    return Container(
      width: 16,
      height: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: active
          ? BankColors.accent.withValues(alpha: 0.5)
          : BankColors.border,
    );
  }
}
