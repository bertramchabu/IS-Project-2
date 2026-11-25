import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/data/models/kpi_metric_model.dart';
import 'package:netvision_ai/services/demo_telemetry_simulator.dart';

void main() {
  const simulator = DemoTelemetrySimulator();
  final timestamp = DateTime.utc(2026, 10, 21);

  test('emits one aligned, presentation-labeled sample for every KPI', () {
    final sample = simulator.sample(
      nodeId: 'node-1',
      elapsed: Duration.zero,
      timestamp: timestamp,
    );

    expect(sample, hasLength(MetricType.values.length));
    expect(sample.map((metric) => metric.metricType).toSet(),
        containsAll(MetricType.values));
    expect(sample.every((metric) => metric.source == DataSource.simulated),
        isTrue);
    expect(sample.every((metric) => metric.timestamp == timestamp), isTrue);
    expect(sample.every((metric) => metric.value.isFinite), isTrue);
  });

  test('simulates normal, precursor, fault, and recovery network phases', () {
    final normal = simulator.sample(
      nodeId: 'node-1',
      elapsed: Duration.zero,
      timestamp: timestamp,
    );
    final precursor = simulator.sample(
      nodeId: 'node-1',
      elapsed: const Duration(seconds: 30),
      timestamp: timestamp,
    );
    final fault = simulator.sample(
      nodeId: 'node-1',
      elapsed: const Duration(seconds: 36),
      timestamp: timestamp,
    );
    final recovery = simulator.sample(
      nodeId: 'node-1',
      elapsed: const Duration(seconds: 54),
      timestamp: timestamp,
    );

    double valueFor(List<KpiMetricModel> sample, MetricType type) =>
        sample.firstWhere((metric) => metric.metricType == type).value;

    expect(valueFor(precursor, MetricType.latency),
        greaterThan(valueFor(normal, MetricType.latency)));
    expect(valueFor(fault, MetricType.packetLoss),
        greaterThan(valueFor(precursor, MetricType.packetLoss)));
    expect(valueFor(recovery, MetricType.latency),
        lessThan(valueFor(fault, MetricType.latency)));
  });
}
