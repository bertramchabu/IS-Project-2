import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../../data/models/prediction_model.dart';
import '../../widgets/web_safe_backdrop_blur.dart';

class FaultGauge extends StatelessWidget {
  final PredictionModel? prediction;
  final List<KpiMetricModel> metrics;
  final String? predictionSource;
  final bool modelApiAvailable;
  final bool modelLoaded;
  final String? statusMessage;
  final double? modelF1Score;
  final VoidCallback? onRetry;

  const FaultGauge({
    super.key,
    this.prediction,
    this.metrics = const [],
    this.predictionSource,
    this.modelApiAvailable = false,
    this.modelLoaded = false,
    this.statusMessage,
    this.modelF1Score,
    this.onRetry,
  });

  // Futuristic Base Colors
  static const _bgColor = Color(0xFF0B111A);
  static const _glassBorderColor = Color(0x33FFFFFF);
  static const _textMuted = Color(0xFF64748B);
  static const _accentCyan = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final probability = prediction?.faultProbability ?? 0.0;
    final hasPrediction = prediction != null;

    final sevColor = !hasPrediction
        ? (modelApiAvailable ? _accentCyan : _textMuted)
        : _severityColor(prediction!.severity);

    final inferenceFailed =
        statusMessage?.toLowerCase().contains('inference failed') ?? false;
    final statusText = inferenceFailed
        ? 'INFERENCE UNAVAILABLE'
        : _statusText(hasPrediction, probability);
    final thresholdExceeded = hasPrediction && probability >= 0.70;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxHeight < 360;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: WebSafeBackdropBlur(
            sigma: 12,
            child: Container(
              decoration: BoxDecoration(
                // Glassmorphic Background Gradient
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _bgColor.withValues(alpha: 0.85),
                    const Color(0xFF141E30).withValues(alpha: 0.65),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _glassBorderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: sevColor.withValues(alpha: 0.08), // Ambient glow
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isTight ? 12 : 18),
              child: Stack(
                children: [
                  // Subtle Background Grid (Sci-Fi HUD feel)
                  Positioned.fill(
                    child: CustomPaint(
                      painter:
                          _GridPainter(color: sevColor.withValues(alpha: 0.05)),
                    ),
                  ),

                  // Main Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        sevColor: sevColor,
                        label: prediction?.severityLabel ??
                            (!modelApiAvailable
                                ? 'OFFLINE'
                                : modelLoaded
                                    ? 'BUFFERING'
                                    : 'NOT READY'),
                      ),
                      const SizedBox(height: 8),

                      // Gauge Area
                      Expanded(
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween:
                                Tween<double>(end: probability.clamp(0.0, 1.0)),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedProbability, _) {
                              return RepaintBoundary(
                                child: SizedBox.expand(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CustomPaint(
                                        key: const ValueKey('fault-gauge-dial'),
                                        painter: _FuturisticGaugePainter(
                                          probability: animatedProbability,
                                          color: sevColor,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: _GaugeReadout(
                                          hasPrediction: hasPrediction,
                                          probability: animatedProbability,
                                          sevColor: sevColor,
                                          statusText: statusText,
                                          thresholdExceeded: thresholdExceeded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      _FooterInfo(
                        prediction: prediction,
                        modelApiAvailable: modelApiAvailable,
                        modelLoaded: modelLoaded,
                        statusMessage: statusMessage,
                        modelF1Score: modelF1Score,
                        metrics: metrics,
                        predictionSource: predictionSource,
                        onRetry: onRetry,
                        isTight: isTight,
                        sevColor: sevColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusText(bool hasPrediction, double probability) {
    if (!hasPrediction) {
      if (!modelApiAvailable) return 'SYS DISCONNECTED';
      return modelLoaded ? 'AWAITING KPI STREAM' : 'MODEL NOT READY';
    }
    if (probability >= 0.70) return 'CRITICAL THRESHOLD';
    if (probability >= 0.40) return 'ELEVATED RISK';
    return 'SYSTEM NOMINAL';
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return const Color(0xFF00FF9D); // Neon Green
      case AlertSeverity.medium:
        return const Color(0xFFFFB300); // Neon Yellow
      case AlertSeverity.high:
        return const Color(0xFFFF6D00); // Neon Orange
      case AlertSeverity.critical:
        return const Color(0xFFFF0055); // Neon Red
    }
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final Color sevColor;
  final String label;
  const _Header({required this.sevColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Neon pulse dot
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sevColor,
            boxShadow: [
              BoxShadow(color: sevColor, blurRadius: 8, spreadRadius: 2),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'FAULT ANTICIPATION',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE2E8F0),
              letterSpacing: 2.0, // Wider tracking for sci-fi feel
              fontFamily:
                  'monospace', // Fallback to monospace if no custom font
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Glass Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: sevColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: sevColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(color: sevColor.withValues(alpha: 0.2), blurRadius: 8),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: sevColor,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _GaugeReadout extends StatelessWidget {
  final bool hasPrediction;
  final double probability;
  final Color sevColor;
  final String statusText;
  final bool thresholdExceeded;

  const _GaugeReadout({
    required this.hasPrediction,
    required this.probability,
    required this.sevColor,
    required this.statusText,
    required this.thresholdExceeded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Digital Value
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Text(
            hasPrediction
                ? '${(probability * 100).toStringAsFixed(1)}%'
                : '--%',
            style: TextStyle(
              fontSize: 54,
              height: 1,
              fontWeight: FontWeight.w900,
              color: sevColor,
              letterSpacing: -1.5,
              shadows: [
                Shadow(color: sevColor.withValues(alpha: 0.8), blurRadius: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Subtitle status
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.1,
          child: Text(
            statusText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: thresholdExceeded
                  ? const Color(0xFFFF0055)
                  : const Color(0xFF94A3B8),
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _FooterInfo extends StatelessWidget {
  final PredictionModel? prediction;
  final bool modelApiAvailable;
  final bool modelLoaded;
  final String? statusMessage;
  final double? modelF1Score;
  final List<KpiMetricModel> metrics;
  final String? predictionSource;
  final VoidCallback? onRetry;
  final bool isTight;
  final Color sevColor;

  const _FooterInfo({
    required this.prediction,
    required this.modelApiAvailable,
    required this.modelLoaded,
    required this.statusMessage,
    required this.modelF1Score,
    required this.metrics,
    required this.predictionSource,
    required this.onRetry,
    required this.isTight,
    required this.sevColor,
  });

  @override
  Widget build(BuildContext context) {
    final showMetrics = (modelF1Score != null ||
            prediction?.computationalSavingsPercent != null) &&
        !isTight;
    final inferenceFailed =
        statusMessage?.toLowerCase().contains('inference failed') ?? false;
    final displayMessage = inferenceFailed
        ? statusMessage!
        : prediction?.message ?? statusMessage ?? 'Awaiting telemetry...';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isTight ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, size: 14, color: sevColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BiLSTM ${prediction?.modelVersionId ?? (!modelApiAvailable ? 'OFFLINE' : modelLoaded ? 'READY' : 'NOT READY')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Icon(Icons.speed_rounded,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                '${prediction?.inferenceTimeMs ?? '—'} ms',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  displayMessage,
                  maxLines: inferenceFailed ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if ((!modelApiAvailable || inferenceFailed) && onRetry != null)
                GestureDetector(
                  onTap: onRetry,
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: sevColor,
                  ),
                ),
            ],
          ),
          if (prediction != null) ...[
            const SizedBox(height: 5),
            _PredictionSourceReadout(
              prediction: prediction!,
              source: predictionSource ?? 'Prediction',
              statusMessage: displayMessage,
              inputTimestamp: prediction!.inputTimestamp,
              color: sevColor,
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 5),
            _LiveKpiReadout(metrics: metrics, color: sevColor),
          ],
          if (showMetrics) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (modelF1Score != null)
                  Text(
                    'F1_SCORE: ${(modelF1Score! * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: sevColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                if (modelF1Score != null &&
                    prediction?.computationalSavingsPercent != null)
                  const SizedBox(width: 12),
                if (prediction?.computationalSavingsPercent != null)
                  Text(
                    'CPU_SAVED: ${prediction!.computationalSavingsPercent}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF00FF9D),
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionSourceReadout extends StatelessWidget {
  final PredictionModel prediction;
  final String source;
  final String? statusMessage;
  final DateTime? inputTimestamp;
  final Color color;

  const _PredictionSourceReadout({
    required this.prediction,
    required this.source,
    required this.statusMessage,
    required this.inputTimestamp,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(prediction.predictionTimestamp);
    final ageText = age.isNegative
        ? 'clock mismatch'
        : age.inSeconds < 60
            ? '${age.inSeconds}s ago'
            : '${age.inMinutes}m ago';
    final sourceLabel =
        source == 'Live BiLSTM API' ? 'MODEL API' : source.toUpperCase();
    final isStale =
        statusMessage?.toLowerCase().contains('inference failed') ?? false;
    final inputAge = inputTimestamp == null
        ? null
        : DateTime.now().difference(inputTimestamp!);
    final inputAgeText = inputAge == null
        ? null
        : inputAge.isNegative
            ? 'clock mismatch'
            : inputAge.inSeconds < 60
                ? '${inputAge.inSeconds}s KPI'
                : '${inputAge.inMinutes}m KPI';

    return Row(
      children: [
        Icon(
          isStale ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: 11,
          color: isStale ? const Color(0xFFFFB300) : color,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            '$sourceLabel · $ageText${inputAgeText == null ? '' : ' · $inputAgeText'}${isStale ? ' · LAST READING' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  isStale ? const Color(0xFFFFB300) : const Color(0xFF94A3B8),
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveKpiReadout extends StatelessWidget {
  final List<KpiMetricModel> metrics;
  final Color color;

  const _LiveKpiReadout({required this.metrics, required this.color});

  @override
  Widget build(BuildContext context) {
    final latestByType = <MetricType, KpiMetricModel>{};
    for (final metric in metrics) {
      final previous = latestByType[metric.metricType];
      if (previous == null || metric.timestamp.isAfter(previous.timestamp)) {
        latestByType[metric.metricType] = metric;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            _sourceLabel,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          for (final type in MetricType.values) ...[
            if (type != MetricType.values.first)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '·',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 10),
                ),
              ),
            Text(
              '${_shortName(type)} ${_formatValue(latestByType[type])}',
              style: TextStyle(
                color: latestByType.containsKey(type)
                    ? const Color(0xFFCBD5E1)
                    : color,
                fontSize: 9,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _sourceLabel {
    if (metrics.every((metric) => metric.source == DataSource.csvReplay)) {
      return 'CSV REPLAY';
    }
    if (metrics.any((metric) => metric.source == DataSource.csvReplay)) {
      return 'MIXED KPI';
    }
    return 'FIRESTORE';
  }

  String _shortName(MetricType type) {
    switch (type) {
      case MetricType.latency:
        return 'LAT';
      case MetricType.jitter:
        return 'JIT';
      case MetricType.packetLoss:
        return 'LOSS';
      case MetricType.retransmissionRate:
        return 'RETX';
      case MetricType.signalStrength:
        return 'SIG';
    }
  }

  String _formatValue(KpiMetricModel? metric) {
    if (metric == null) return '--';
    final value = metric.value.toStringAsFixed(1);
    return switch (metric.metricType) {
      MetricType.latency || MetricType.jitter => '$value${metric.unit}',
      MetricType.packetLoss || MetricType.retransmissionRate => '$value%',
      MetricType.signalStrength => value,
    };
  }
}

// ---------------------------------------------------------------------------

/// Background Grid for Sci-Fi feel
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------

class _FuturisticGaugePainter extends CustomPainter {
  final double probability;
  final Color color;

  _FuturisticGaugePainter({required this.probability, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const tickCount = 20;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final radius = math.min(size.width * 0.45, size.height * 0.85);
    final pivot = Offset(size.width / 2, size.height);
    final arcRect = Rect.fromCircle(center: pivot, radius: radius);
    final p = probability.clamp(0.0, 1.0);

    // 1. Dark Track (Base)
    canvas.drawArc(
      arcRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );

    // 2. Neon Active Arc (with heavy glow)
    final activeSweep = sweepAngle * p;
    if (activeSweep > 0.001) {
      // Outer Glow
      canvas.drawArc(
        arcRect,
        startAngle,
        activeSweep,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Core Line
      canvas.drawArc(
        arcRect,
        startAngle,
        activeSweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }

    // 3. Ticks & Labels (Futuristic HUD)
    for (var i = 0; i <= tickCount; i++) {
      final fraction = i / tickCount;
      final angle = startAngle + sweepAngle * fraction;
      final majorTick = i.isEven;

      final innerRadius = radius - (majorTick ? 24.0 : 16.0);
      final outerRadius = radius - 6.0;

      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // Draw Tick
      canvas.drawLine(
        Offset(pivot.dx + innerRadius * cosA, pivot.dy + innerRadius * sinA),
        Offset(pivot.dx + outerRadius * cosA, pivot.dy + outerRadius * sinA),
        Paint()
          ..color = majorTick
              ? color.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = majorTick ? 2.5 : 1.0
          ..strokeCap = StrokeCap.round,
      );

      // Draw Label (Only for major ticks)
      if (majorTick) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${(fraction * 100).round()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final labelRadius = radius - 40;
        final lx = pivot.dx + labelRadius * cosA - textPainter.width / 2;
        final ly = pivot.dy + labelRadius * sinA - textPainter.height / 2;

        textPainter.paint(canvas, Offset(lx, ly));
      }
    }

    // 4. High-Tech Needle
    final needleAngle = startAngle + sweepAngle * p;
    final needleLength = radius * 0.7;
    final tip = Offset(
      pivot.dx + needleLength * math.cos(needleAngle),
      pivot.dy + needleLength * math.sin(needleAngle),
    );

    // Needle Glow
    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Needle Core
    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // 5. Center Hub (Digital)
    canvas.drawCircle(pivot, 14, Paint()..color = const Color(0xFF0B111A));
    canvas.drawCircle(
      pivot,
      14,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(pivot, 6, Paint()..color = color);

    // 6. Threshold Marker (Sleek Line)
    const thresholdAngle = startAngle + sweepAngle * 0.70;
    final tStart = Offset(
      pivot.dx + (radius - 2) * math.cos(thresholdAngle),
      pivot.dy + (radius - 2) * math.sin(thresholdAngle),
    );
    final tEnd = Offset(
      pivot.dx + (radius + 18) * math.cos(thresholdAngle),
      pivot.dy + (radius + 18) * math.sin(thresholdAngle),
    );
    canvas.drawLine(
      tStart,
      tEnd,
      Paint()
        ..color = const Color(0xFFFF0055) // Red warning
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FuturisticGaugePainter old) =>
      old.probability != probability || old.color != color;
}
