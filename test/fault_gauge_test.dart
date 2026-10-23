import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/data/models/alert_model.dart';
import 'package:netvision_ai/data/models/kpi_metric_model.dart';
import 'package:netvision_ai/data/models/prediction_model.dart';
import 'package:netvision_ai/presentation/dashboard/widgets/fault_gauge.dart';

void main() {
  testWidgets('fills the speedometer area and displays a percentage reading',
      (tester) async {
    final prediction = PredictionModel(
      predictionId: 'prediction-1',
      nodeId: 'node-1',
      modelVersionId: 'test-model',
      faultProbability: 0.725,
      severity: AlertSeverity.high,
      inputFeatures: const [],
      adaptiveReductionApplied: false,
      predictionTimestamp: DateTime.utc(2026),
      inputTimestamp: DateTime.utc(2026),
      triggeredBy: 'test',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 500,
              child: FaultGauge(
                prediction: prediction,
                predictionSource: 'Live BiLSTM API',
                metrics: [
                  KpiMetricModel(
                    metricId: 'latency-1',
                    nodeId: 'node-1',
                    metricType: MetricType.latency,
                    value: 30.8,
                    unit: 'ms',
                    timestamp: DateTime.utc(2026),
                    source: DataSource.api,
                  ),
                  KpiMetricModel(
                    metricId: 'loss-1',
                    nodeId: 'node-1',
                    metricType: MetricType.packetLoss,
                    value: 0.1,
                    unit: '%',
                    timestamp: DateTime.utc(2026),
                    source: DataSource.api,
                  ),
                ],
                modelApiAvailable: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('72.5%'), findsOneWidget);
    expect(find.textContaining('MODEL API'), findsOneWidget);
    expect(find.text('LAT 30.8ms'), findsOneWidget);
    expect(find.text('LOSS 0.1%'), findsOneWidget);
    final dialSize = tester.getSize(
      find.byKey(const ValueKey('fault-gauge-dial')),
    );
    expect(dialSize.width, greaterThan(250));
    expect(dialSize.height, greaterThan(150));
  });

  testWidgets('indicates that a prediction is unavailable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 500,
            child: FaultGauge(modelApiAvailable: false),
          ),
        ),
      ),
    );

    expect(find.text('--%'), findsOneWidget);
    expect(find.text('SYS DISCONNECTED'), findsOneWidget);
  });

  testWidgets('marks the last prediction when live inference fails',
      (tester) async {
    final prediction = PredictionModel(
      predictionId: 'prediction-1',
      nodeId: 'node-1',
      modelVersionId: 'test-model',
      faultProbability: 0.25,
      severity: AlertSeverity.low,
      inputFeatures: const [],
      adaptiveReductionApplied: false,
      predictionTimestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      triggeredBy: 'test',
      message: 'Previous prediction was healthy.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 500,
            child: FaultGauge(
              prediction: prediction,
              predictionSource: 'Live BiLSTM API',
              statusMessage: 'Live inference failed: unavailable',
              modelApiAvailable: false,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('LAST READING'), findsOneWidget);
    expect(find.text('Live inference failed: unavailable'), findsOneWidget);
  });
}
