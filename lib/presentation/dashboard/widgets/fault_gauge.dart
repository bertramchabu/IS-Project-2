import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/models/prediction_model.dart';

class FaultGauge extends StatelessWidget {
  final PredictionModel? prediction;
  final bool modelApiAvailable;
  final String? statusMessage;
  final double? modelF1Score;
  final VoidCallback? onRetry;

  const FaultGauge({
    super.key,
    this.prediction,
    this.modelApiAvailable = false,
    this.statusMessage,
    this.modelF1Score,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    const surfaceColor = Color(0xFF111827);
    const borderColor = Color(0xFF1F2A3A);
    const textPrimary = Color(0xFFF1F5F9);
    const textMuted = Color(0xFF64748B);

    final probability = prediction?.faultProbability ?? 0;
    final sevColor = prediction == null
        ? modelApiAvailable
            ? const Color(0xFF00E5FF)
            : textMuted
        : _severityColor(prediction!.severity);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sevColor,
                        boxShadow: [
                          BoxShadow(
                            color: sevColor.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'FAULT ANTICIPATION GAUGE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sevColor.withOpacity(0.4)),
                ),
                child: Text(
                  prediction?.severityLabel ??
                      (modelApiAvailable ? 'BUFFERING' : 'OFFLINE'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: sevColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Central Radial Gauge
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gaugeWidth = math.min(300.0, constraints.maxWidth);
                final gaugeHeight = math.min(190.0, constraints.maxHeight);
                return Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: probability),
                    duration: const Duration(milliseconds: 850),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedProbability, _) => SizedBox(
                      width: gaugeWidth,
                      height: gaugeHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _SpeedometerPainter(
                              probability: animatedProbability,
                              color: sevColor,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  prediction == null
                                      ? '--'
                                      : '${(animatedProbability * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 32,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: sevColor,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  prediction == null
                                      ? modelApiAvailable
                                          ? 'BUFFERING KPI DATA'
                                          : 'MODEL CONNECTION REQUIRED'
                                      : probability >= 0.70
                                          ? 'THRESHOLD EXCEEDED'
                                          : probability >= 0.40
                                              ? 'ELEVATED RISK'
                                              : 'NOMINAL (HEALTHY)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: probability >= 0.70
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF94A3B8),
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Footer info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.memory_rounded,
                        size: 14, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'BiLSTM ${prediction?.modelVersionId ?? (modelApiAvailable ? 'loading' : 'offline')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.speed_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      '${prediction?.inferenceTimeMs ?? '—'} ms',
                      style: const TextStyle(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prediction?.message ??
                            statusMessage ??
                            'Waiting for live KPI data',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ),
                    if (!modelApiAvailable && onRetry != null)
                      IconButton(
                        onPressed: onRetry,
                        tooltip: 'Retry model connection',
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        visualDensity: VisualDensity.compact,
                        color: const Color(0xFF00E5FF),
                      ),
                  ],
                ),
                if (modelF1Score != null ||
                    prediction?.computationalSavingsPercent != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (modelF1Score != null)
                        Text(
                          'F1 ${(modelF1Score! * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      if (modelF1Score != null &&
                          prediction?.computationalSavingsPercent != null)
                        const SizedBox(width: 10),
                      if (prediction?.computationalSavingsPercent != null)
                        Text(
                          'Compute saved ${prediction!.computationalSavingsPercent}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return const Color(0xFF22C55E);
      case AlertSeverity.medium:
        return const Color(0xFFF59E0B);
      case AlertSeverity.high:
        return const Color(0xFFFB923C);
      case AlertSeverity.critical:
        return const Color(0xFFEF4444);
    }
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double probability;
  final Color color;

  _SpeedometerPainter({required this.probability, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const tickCount = 20;
    const startAngle = math.pi;
    const sweepAngle = math.pi;
    final radius = math.min(size.width * 0.43, size.height * 0.65);
    final pivot = Offset(size.width / 2, size.height * 0.72);
    final arcRect = Rect.fromCircle(center: pivot, radius: radius);

    canvas.drawArc(
      arcRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFF1F2A3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round,
    );

    const riskColors = [
      Color(0xFF22C55E),
      Color(0xFF84CC16),
      Color(0xFFF59E0B),
      Color(0xFFF97316),
      Color(0xFFEF4444),
    ];
    for (var i = 0; i < riskColors.length; i++) {
      canvas.drawArc(
        arcRect,
        startAngle + sweepAngle * i / riskColors.length,
        sweepAngle / riskColors.length - 0.025,
        false,
        Paint()
          ..color = riskColors[i].withOpacity(0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    final activeSweep = sweepAngle * probability.clamp(0.0, 1.0);
    if (activeSweep > 0) {
      canvas.drawArc(
        arcRect,
        startAngle,
        activeSweep,
        false,
        Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawArc(
        arcRect,
        startAngle,
        activeSweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i <= tickCount; i++) {
      final fraction = i / tickCount;
      final angle = startAngle + sweepAngle * fraction;
      final majorTick = i % 2 == 0;
      final innerRadius = radius - (majorTick ? 17 : 11);
      final outerRadius = radius - 3;
      final tickPaint = Paint()
        ..color = majorTick ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)
        ..strokeWidth = majorTick ? 2 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(
          pivot.dx + innerRadius * math.cos(angle),
          pivot.dy + innerRadius * math.sin(angle),
        ),
        Offset(
          pivot.dx + outerRadius * math.cos(angle),
          pivot.dy + outerRadius * math.sin(angle),
        ),
        tickPaint,
      );

      if (majorTick) {
        final label = TextPainter(
          text: TextSpan(
            text: '${(fraction * 100).round()}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelRadius = radius - 31;
        label.paint(
          canvas,
          Offset(
            pivot.dx + labelRadius * math.cos(angle) - label.width / 2,
            pivot.dy + labelRadius * math.sin(angle) - label.height / 2,
          ),
        );
      }
    }

    final needleAngle = startAngle + sweepAngle * probability.clamp(0.0, 1.0);
    final needleLength = radius * 0.76;
    final needleTip = Offset(
      pivot.dx + needleLength * math.cos(needleAngle),
      pivot.dy + needleLength * math.sin(needleAngle),
    );
    canvas.drawLine(
      pivot,
      needleTip,
      Paint()
        ..color = color.withOpacity(0.25)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      pivot,
      needleTip,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      pivot,
      8,
      Paint()..color = const Color(0xFF0B1220),
    );
    canvas.drawCircle(
      pivot,
      5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    final thresholdAngle = startAngle + sweepAngle * 0.70;
    final thresholdPoint = Offset(
      pivot.dx + (radius + 12) * math.cos(thresholdAngle),
      pivot.dy + (radius + 12) * math.sin(thresholdAngle),
    );
    canvas.drawCircle(
      thresholdPoint,
      3,
      Paint()..color = const Color(0xFFEF4444),
    );
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.probability != probability || old.color != color;
}
