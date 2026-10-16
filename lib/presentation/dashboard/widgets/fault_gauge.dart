import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/models/prediction_model.dart';

class FaultGauge extends StatelessWidget {
  final PredictionModel? prediction;
  final bool modelApiAvailable;
  final String? statusMessage;
  final double? modelF1Score;

  const FaultGauge({
    super.key,
    this.prediction,
    this.modelApiAvailable = false,
    this.statusMessage,
    this.modelF1Score,
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
            child: Center(
              child: CustomPaint(
                size: const Size(190, 190),
                painter: _RadialGaugePainter(
                  probability: probability,
                  color: sevColor,
                ),
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          prediction == null
                              ? '--'
                              : '${(probability * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: sevColor,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                            fontSize: 10,
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
                ),
              ),
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
                Text(
                  prediction?.message ?? statusMessage ?? 'Waiting for live KPI data',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: textMuted),
                ),
                if (modelF1Score != null || prediction?.computationalSavingsPercent != null) ...[
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

class _RadialGaugePainter extends CustomPainter {
  final double probability;
  final Color color;

  _RadialGaugePainter({required this.probability, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;

    // Background track arc
    final bgPaint = Paint()
      ..color = const Color(0xFF1F2A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value active arc
    final valSweep = (sweepAngle * probability.clamp(0.0, 1.0));
    if (valSweep > 0) {
      final valuePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        valSweep,
        false,
        valuePaint,
      );
    }

    // 70% Alert Threshold Tick Mark
    final thresholdAngle = startAngle + sweepAngle * 0.70;
    final markerPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final innerPoint = Offset(
      center.dx + (radius - 10) * math.cos(thresholdAngle),
      center.dy + (radius - 10) * math.sin(thresholdAngle),
    );
    final outerPoint = Offset(
      center.dx + (radius + 10) * math.cos(thresholdAngle),
      center.dy + (radius + 10) * math.sin(thresholdAngle),
    );
    canvas.drawLine(innerPoint, outerPoint, markerPaint);
  }

  @override
  bool shouldRepaint(_RadialGaugePainter old) =>
      old.probability != probability || old.color != color;
}
