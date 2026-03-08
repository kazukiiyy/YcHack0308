import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../theme.dart';

class StMarketAllocation extends StatelessWidget {
  final List<StAllocation> allocations;

  const StMarketAllocation({super.key, required this.allocations});

  static const _colors = [
    AppColors.accent,
    AppColors.emerald,
    AppColors.amber,
  ];

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
                const Icon(Icons.pie_chart_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'ST Market Allocation',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: _buildSections(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ..._buildLegend(context),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildAllocationTable(context),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final total = allocations.fold<double>(0, (sum, a) => sum + a.allocated);
    return List.generate(allocations.length, (i) {
      final pct = (allocations[i].allocated / total * 100);
      return PieChartSectionData(
        value: allocations[i].allocated,
        color: _colors[i % _colors.length],
        radius: 28,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: monoStyle(size: 10, color: Colors.white, weight: FontWeight.w700),
      );
    });
  }

  List<Widget> _buildLegend(BuildContext context) {
    return List.generate(allocations.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _colors[i % _colors.length],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                allocations[i].name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
            Text(
              _fmtShort(allocations[i].allocated),
              style: monoStyle(size: 12, weight: FontWeight.w600),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAllocationTable(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    );
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: Text('ASSET', style: headerStyle)),
            SizedBox(width: 70, child: Text('ALLOCATED', style: headerStyle)),
            SizedBox(width: 70, child: Text('AVAILABLE', style: headerStyle)),
          ],
        ),
        const SizedBox(height: 8),
        ...allocations.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      a.name,
                      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(_fmtShort(a.allocated), style: monoStyle(size: 11)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      _fmtShort(a.available),
                      style: monoStyle(size: 11, color: AppColors.emerald),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  String _fmtShort(double v) {
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(0)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}
