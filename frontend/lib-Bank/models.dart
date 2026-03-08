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
