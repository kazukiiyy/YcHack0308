import 'models.dart';

final List<StAllocation> demoAllocations = [
  const StAllocation(
    name: 'Real Estate ST',
    allocated: 480000000,
    available: 120000000,
  ),
  const StAllocation(
    name: 'Corporate Bond ST',
    allocated: 350000000,
    available: 90000000,
  ),
  const StAllocation(
    name: 'Treasury Fund ST',
    allocated: 210000000,
    available: 55000000,
  ),
];

final List<double> demoSparkline = [
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
  0.00,
];

final List<StProduct> demoProducts = [
  const StProduct(
    id: 'rst-001',
    name: 'Tokyo Prime Real Estate Fund',
    category: 'Real Estate ST',
    description:
        'Premium commercial real estate portfolio in central Tokyo districts.',
    priceUsdt: 5000,
    annualYield: 4.2,
    imageIcon: '🏢',
  ),
  const StProduct(
    id: 'cbs-001',
    name: 'Asia Corporate Bond Package',
    category: 'Corporate Bond ST',
    description:
        'Diversified investment-grade corporate bonds across Asia-Pacific.',
    priceUsdt: 2500,
    annualYield: 3.8,
    imageIcon: '📊',
  ),
  const StProduct(
    id: 'tfs-001',
    name: 'Stable Treasury Fund',
    category: 'Treasury Fund ST',
    description:
        'Government-backed treasury securities for capital preservation.',
    priceUsdt: 1000,
    annualYield: 2.5,
    imageIcon: '🏛️',
  ),
  const StProduct(
    id: 'rst-002',
    name: 'Osaka Logistics REIT',
    category: 'Real Estate ST',
    description:
        'Industrial and logistics properties in the Osaka-Kobe corridor.',
    priceUsdt: 3000,
    annualYield: 5.1,
    imageIcon: '🏭',
  ),
  const StProduct(
    id: 'cbs-002',
    name: 'Green Energy Bond ST',
    category: 'Corporate Bond ST',
    description: 'ESG-compliant renewable energy project bonds.',
    priceUsdt: 1500,
    annualYield: 4.5,
    imageIcon: '🌱',
  ),
];
