import 'models.dart';

final List<BridgeTransaction> demoTransactions = [
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(seconds: 12)),
    publicTxHash: '0xa3f8…c4d1',
    amountUsdt: 2500000,
    status: BridgeStatus.syncing,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(seconds: 34)),
    publicTxHash: '0x91b2…e7f3',
    amountUsdt: 850000,
    status: BridgeStatus.locked,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 1, seconds: 10)),
    publicTxHash: '0xd4e6…12ab',
    amountUsdt: 12000000,
    status: BridgeStatus.credited,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 2, seconds: 5)),
    publicTxHash: '0x7c0f…9a82',
    amountUsdt: 430000,
    status: BridgeStatus.credited,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
    publicTxHash: '0xbe53…47dc',
    amountUsdt: 6700000,
    status: BridgeStatus.syncing,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 4, seconds: 22)),
    publicTxHash: '0x1f8a…b3c0',
    amountUsdt: 1100000,
    status: BridgeStatus.credited,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 5, seconds: 48)),
    publicTxHash: '0x62d4…f1e9',
    amountUsdt: 9800000,
    status: BridgeStatus.credited,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
    publicTxHash: '0xc9a1…53bf',
    amountUsdt: 350000,
    status: BridgeStatus.credited,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 8, seconds: 15)),
    publicTxHash: '0x4b7e…d802',
    amountUsdt: 15600000,
    status: BridgeStatus.credited,
  ),
  BridgeTransaction(
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    publicTxHash: '0x08fc…a6e5',
    amountUsdt: 720000,
    status: BridgeStatus.syncing,
  ),
];

final List<StAllocation> demoAllocations = [
  const StAllocation(name: 'Real Estate ST', allocated: 480000000, available: 120000000),
  const StAllocation(name: 'Corporate Bond ST', allocated: 350000000, available: 90000000),
  const StAllocation(name: 'Treasury Fund ST', allocated: 210000000, available: 55000000),
];

final List<double> demoSparkline = [
  0.82, 0.85, 0.91, 0.88, 0.95, 1.02, 1.08, 1.05, 1.12, 1.15, 1.18, 1.20,
];
