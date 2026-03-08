import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Widget? trailing;
  final IconData icon;
  final Color iconColor;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trailing,
    required this.icon,
    this.iconColor = BankColors.accent,
  });

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
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: bankMono(size: 26, weight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            ],
            if (trailing != null) ...[
              const SizedBox(height: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class SparklineWidget extends StatelessWidget {
  final List<double> data;
  final Color color;

  const SparklineWidget({super.key, required this.data, this.color = BankColors.emerald});

  @override
  Widget build(BuildContext context) {
    final nonZero = data.where((v) => v > 0).toList();
    if (nonZero.isEmpty) {
      return SizedBox(
        height: 32,
        width: 100,
        child: Center(
          child: Text('No data', style: bankMono(size: 10, color: BankColors.textSecondary)),
        ),
      );
    }
    return SizedBox(
      height: 32,
      width: 100,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: data.reduce((a, b) => a < b ? a : b) * 0.95,
          maxY: data.reduce((a, b) => a > b ? a : b) * 1.05,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

class NetworkStatusIndicator extends StatelessWidget {
  final String label;
  final bool isOnline;

  const NetworkStatusIndicator({super.key, required this.label, this.isOnline = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? BankColors.emerald : BankColors.red,
            boxShadow: [
              BoxShadow(
                color: (isOnline ? BankColors.emerald : BankColors.red).withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: bankMono(size: 11, color: BankColors.textSecondary)),
      ],
    );
  }
}
