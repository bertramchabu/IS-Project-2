import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../data/models/kpi_metric_model.dart';

class KpiLineChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<KpiMetricModel> metrics;
  final Color color;
  final double? warningThreshold;
  final double? criticalThreshold;

  const KpiLineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.metrics,
    required this.color,
    this.warningThreshold,
    this.criticalThreshold,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return _emptyCard(context, title, unit, color);
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < metrics.length; i++) {
      spots.add(FlSpot(i.toDouble(), metrics[i].value));
    }

    final values = metrics.map((m) => m.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding =
        maxY == minY ? (maxY.abs() * 0.05).clamp(1, double.infinity) : (maxY - minY) * 0.2;
    final latest = metrics.last.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  '${latest.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            StreamBuilder<int>(
              stream:
                  Stream<int>.periodic(const Duration(seconds: 1), (tick) => tick),
              initialData: 0,
              builder: (context, _) {
                final age = DateTime.now().difference(metrics.last.timestamp);
                final isLive =
                    age >= Duration.zero && age <= const Duration(seconds: 5);
                final updateText = age < Duration.zero
                    ? 'timestamp in future'
                    : age.inSeconds < 60
                        ? 'updated ${age.inSeconds}s ago'
                        : 'updated ${age.inMinutes}m ago';
                return Text(
                  '${metrics.length} samples • ${isLive ? 'LIVE' : 'STALE'} • $updateText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isLive ? Colors.greenAccent : Colors.white54,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: (minY - padding).clamp(0, double.infinity),
                  maxY: maxY + padding,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (warningThreshold != null)
                      HorizontalLine(
                        y: warningThreshold!,
                        color: Colors.orange.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    if (criticalThreshold != null)
                      HorizontalLine(
                        y: criticalThreshold!,
                        color: Colors.red.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(
      BuildContext context, String title, String unit, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, color: color.withValues(alpha: 0.5), size: 40),
                  const SizedBox(height: 8),
                  const Text('No data available',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}