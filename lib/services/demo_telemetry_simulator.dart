import 'dart:math' as math;

import '../data/models/kpi_metric_model.dart';

class DemoTelemetrySimulator {
  const DemoTelemetrySimulator();

  static const cycleDuration = Duration(seconds: 84);
  static const _warmupSeconds = 12;
  static const _precursorSeconds = 20;
  static const _faultSeconds = 12;
  static const _recoverySeconds = 20;

  List<KpiMetricModel> sample({
    required String nodeId,
    required Duration elapsed,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final cycleSecond = elapsed.inSeconds % cycleDuration.inSeconds;
    const precursorEnd = _warmupSeconds + _precursorSeconds;
    const faultEnd = precursorEnd + _faultSeconds;
    const recoveryEnd = faultEnd + _recoverySeconds;

    var precursor = 0.0;
    var recovery = 0.0;
    final activeFault = cycleSecond >= precursorEnd && cycleSecond < faultEnd;

    if (cycleSecond >= _warmupSeconds && cycleSecond < precursorEnd) {
      precursor = (cycleSecond - _warmupSeconds) / _precursorSeconds;
    } else if (cycleSecond >= faultEnd && cycleSecond < recoveryEnd) {
      recovery = 1 - (cycleSecond - faultEnd) / _recoverySeconds;
    }

    final seconds = elapsed.inMilliseconds / 1000;
    final baselineLatency = 30 + 6 * math.sin(seconds * 0.31);
    final baselineJitter = 3.5 + 1.2 * math.sin(seconds * 0.23);
    final baselineLoss = 0.08 + 0.03 * math.sin(seconds * 0.41).abs();
    final baselineRetransmission = 0.4 + 0.08 * math.sin(seconds * 0.19);
    final baselineSignal = -60 + 3 * math.sin(seconds * 0.13);

    final latency =
        baselineLatency + (activeFault ? 190 : 60 * precursor + 40 * recovery);
    final jitter =
        baselineJitter + (activeFault ? 50 : 15 * precursor + 10 * recovery);
    final packetLoss =
        baselineLoss + (activeFault ? 8 : 1.8 * precursor + 1.5 * recovery);
    final retransmissionRate = baselineRetransmission +
        (activeFault ? 12 : 4.5 * precursor + 2 * recovery);

    final values = <MetricType, double>{
      MetricType.latency: latency,
      MetricType.jitter: jitter,
      MetricType.packetLoss: packetLoss,
      MetricType.retransmissionRate: retransmissionRate,
      MetricType.signalStrength: baselineSignal,
    };
    final quality = activeFault || precursor >= 0.5
        ? DataQuality.poor
        : precursor > 0 || recovery > 0
            ? DataQuality.fair
            : DataQuality.good;

    return values.entries.map((entry) {
      return KpiMetricModel(
        metricId:
            'demo-$nodeId-${now.microsecondsSinceEpoch}-${entry.key.name}',
        nodeId: nodeId,
        metricType: entry.key,
        value: entry.value,
        unit: _unitFor(entry.key),
        timestamp: now,
        source: DataSource.simulated,
        quality: quality,
      );
    }).toList();
  }

  String _unitFor(MetricType type) {
    switch (type) {
      case MetricType.latency:
      case MetricType.jitter:
        return 'ms';
      case MetricType.packetLoss:
      case MetricType.retransmissionRate:
        return '%';
      case MetricType.signalStrength:
        return 'dBm';
    }
  }
}
