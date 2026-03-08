import 'package:flutter/material.dart';
import '../../shared/models.dart';
import '../../shared/demo_data.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import 'checkout_page.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: EndUserColors.accent, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.account_balance, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('ST Market', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: EndUserColors.accent),
              label: Text('50,000 USDT', style: endUserMono(size: 12, weight: FontWeight.w600)),
              backgroundColor: EndUserColors.surfaceVariant,
              side: const BorderSide(color: EndUserColors.border),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ヒーローバナー
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Security Token Marketplace',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Invest in tokenized real-world assets with USDT',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatChip(label: '5 Products', icon: Icons.token_rounded),
                    const SizedBox(width: 12),
                    _StatChip(label: 'Pay with USDT', icon: Icons.currency_exchange_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Available Products',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: EndUserColors.textPrimary)),
          const SizedBox(height: 12),
          ...demoProducts.map((product) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProductCard(
                  product: product,
                  onTap: () => _showCheckout(context, product),
                ),
              )),
        ],
      ),
    );
  }

  void _showCheckout(BuildContext context, StProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutSheet(product: product),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
