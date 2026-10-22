import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/data/models/kpi_metric_model.dart';
import 'package:netvision_ai/services/csv_telemetry_replay.dart';

const _csv = '''
timestamp,node_id,latency,jitter,packet_loss,retransmission_rate,signal_strength
2026-06-01 08:00:00,Node-B,20,2,0.1,0.2,-50
2026-06-01 08:00:00,Node-A,10,1,0.05,0.1,-60
2026-06-01 08:00:01,Node-A,11,1.5,0.06,0.12,-59
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled network KPI dataset', () async {
    final replay = await CsvTelemetryReplay.load();

    expect(replay.sourceIds, [
      'Node-A_CoreSwitch',
      'Node-B_Gateway',
      'Node-C_Distribution',
      'Node-D_AccessPoint',
    ]);
  });

  test('maps sorted CSV locations to the selected dashboard node', () {
    final replay = CsvTelemetryReplay.fromCsv(_csv);
    final timestamp = DateTime.utc(2026, 10, 22);

    final sample = replay.sample(
      locationIndex: 0,
      nodeId: 'firebase-node',
      timestamp: timestamp,
    );

    expect(replay.sourceIds, ['Node-A', 'Node-B']);
    expect(sample, hasLength(MetricType.values.length));
    expect(sample.every((metric) => metric.nodeId == 'firebase-node'), isTrue);
    expect(sample.every((metric) => metric.timestamp == timestamp), isTrue);
    expect(sample.every((metric) => metric.source == DataSource.csvReplay),
        isTrue);
    expect(
      sample
          .firstWhere((metric) => metric.metricType == MetricType.latency)
          .value,
      10,
    );
  });

  test('advances through each location and wraps when its rows end', () {
    final replay = CsvTelemetryReplay.fromCsv(_csv);

    double nextLatency() => replay
        .sample(
          locationIndex: 0,
          nodeId: 'node',
          timestamp: DateTime.utc(2026),
        )
        .firstWhere((metric) => metric.metricType == MetricType.latency)
        .value;

    expect([nextLatency(), nextLatency(), nextLatency()], [10, 11, 10]);
  });

  test('rejects invalid CSV schemas and non-numeric KPI values', () {
    expect(
      () => CsvTelemetryReplay.fromCsv('node_id,latency\\nNode-A,10'),
      throwsFormatException,
    );
    expect(
      () => CsvTelemetryReplay.fromCsv(_csv.replaceFirst(',10,1,', ',bad,1,')),
      throwsFormatException,
    );
  });
}
