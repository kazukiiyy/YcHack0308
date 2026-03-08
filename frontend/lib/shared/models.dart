enum BridgeStatus { locked, syncing, credited }

class BridgeTransaction {
  final DateTime timestamp;
  final String publicTxHash;
  final double amountUsdt;
  final BridgeStatus status;

  const BridgeTransaction({
    required this.timestamp,
    required this.publicTxHash,
    required this.amountUsdt,
    required this.status,
  });

  BridgeTransaction copyWith({BridgeStatus? status}) {
    return BridgeTransaction(
      timestamp: timestamp,
      publicTxHash: publicTxHash,
      amountUsdt: amountUsdt,
      status: status ?? this.status,
    );
  }
}

class StAllocation {
  final String name;
  final double allocated;
  final double available;

  const StAllocation({
    required this.name,
    required this.allocated,
    required this.available,
  });

  double get total => allocated + available;
}

/// エンドユーザー向けの ST 商品。
class StProduct {
  final String id;
  final String name;
  final String category;
  final String description;
  final double priceUsdt;
  final double annualYield;
  final String imageIcon;

  const StProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priceUsdt,
    required this.annualYield,
    this.imageIcon = '🏢',
  });
}
