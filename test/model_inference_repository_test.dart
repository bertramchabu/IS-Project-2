import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/data/models/kpi_metric_model.dart';
import 'package:netvision_ai/data/repositories/model_inference_repository.dart';

void main() {
  final repository = ModelInferenceRepository();

  test('builds a ten-step input from complete, time-aligned KPI samples', () {
    final start = DateTime.utc(2026, 10, 17);
    final metrics = <KpiMetricModel>[];
    const types = MetricType.values;

    for (var timestep = 0; timestep < 10; timestep++) {
      for (var index = 0; index < types.length; index++) {
        metrics.add(
          KpiMetricModel(
            metricId: '$timestep-${types[index].name}',
            nodeId: 'node-1',
            metricType: types[index],
            value: timestep * 10 + index.toDouble(),
            unit: '',
            timestamp: start
                .add(Duration(seconds: timestep, milliseconds: index * 100)),
            source: DataSource.api,
          ),
        );
      }
    }

    final window = repository.latestWindow(metrics);

    expect(window, isNotNull);
    expect(window!.sampleCount, 10);
    expect(window.isReady, isTrue);
    expect(window.sequence, hasLength(10));
    expect(window.sequence.first['latency'], 0);
    expect(window.sequence.last['signal_strength'], 94);
    expect(window.timestamp,
        start.add(const Duration(seconds: 9, milliseconds: 400)));
  });

  test('does not count incomplete metric groups as model timesteps', () {
    final start = DateTime.utc(2026, 10, 17);
    final metrics = [
      KpiMetricModel(
        metricId: 'latency-1',
        nodeId: 'node-1',
        metricType: MetricType.latency,
        value: 12,
        unit: 'ms',
        timestamp: start,
        source: DataSource.api,
      ),
    ];

    final window = repository.latestWindow(metrics);

    expect(window, isNull);
  });
}
