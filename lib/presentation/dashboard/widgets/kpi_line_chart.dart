// kpi_line_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../widgets/glass_ui.dart';

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
    if (metrics.isEmpty) return _emptyCard(context, title, unit, color);

    final spots = <FlSpot>[];
    for (var i = 0; i < metrics.length; i++) {
      spots.add(FlSpot(i.toDouble(), metrics[i].value));
    }

    final values = metrics.map((m) => m.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = maxY == minY
        ? (maxY.abs() * 0.05).clamp(1, double.infinity)
        : (maxY - minY) * 0.2;
    final latest = metrics.last.value;

    return GlassSurface(
      padding: const EdgeInsets.all(12),
      radius: 16,
      tint: const Color(0xFF111827),
      blurSigma: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5)),
              Text(
                '${latest.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8)
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StreamBuilder<int>(
            stream: Stream<int>.periodic(
                const Duration(seconds: 1), (tick) => tick),
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
              final source = metrics.every(
                (metric) => metric.source == DataSource.csvReplay,
              )
                  ? 'CSV REPLAY'
                  : metrics.any(
                          (metric) => metric.source == DataSource.csvReplay)
                      ? 'MIXED'
                      : 'FIRESTORE';
              return Text(
                '$source • ${metrics.length} samples • ${isLive ? 'LIVE' : 'STALE'} • $updateText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: isLive ? const Color(0xFF00FF9D) : Colors.white54,
                    fontFamily: 'monospace'),
              );
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    shadow: Shadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 12), // Neon glow
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.0)
                        ],
                      ),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(horizontalLines: [
                  if (warningThreshold != null)
                    HorizontalLine(
                        y: warningThreshold!,
                        color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                        strokeWidth: 1,
                        dashArray: [4, 4]),
                  if (criticalThreshold != null)
                    HorizontalLine(
                        y: criticalThreshold!,
                        color: const Color(0xFFFF0055).withValues(alpha: 0.4),
                        strokeWidth: 1,
                        dashArray: [4, 4]),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(
      BuildContext context, String title, String unit, Color color) {
    return GlassSurface(
      padding: const EdgeInsets.all(12),
      radius: 16,
      tint: const Color(0xFF111827),
      blurSigma: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Expanded(
            child: Center(
              child: Text(
                'No data available',
                style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
