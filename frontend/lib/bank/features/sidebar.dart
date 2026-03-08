import 'package:flutter/material.dart';
import '../theme.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AppSidebar({super.key, required this.selectedIndex, required this.onSelect});

  static const _items = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.swap_horiz_rounded, 'Bridge'),
    _NavItem(Icons.account_balance_rounded, 'Markets'),
    _NavItem(Icons.analytics_rounded, 'Analytics'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      color: BankColors.sidebarBg,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: BankColors.accent, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.account_balance, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 32),
          ...List.generate(_items.length, (i) {
            final selected = i == selectedIndex;
            return Tooltip(
              message: _items[i].label,
              preferBelow: false,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: selected ? const Border(left: BorderSide(color: BankColors.accent, width: 3)) : null,
                  ),
                  child: Icon(_items[i].icon, size: 22, color: selected ? BankColors.accent : BankColors.textSecondary),
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: BankColors.surfaceVariant,
              child: Text('TO', style: bankMono(size: 10, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
