import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/services/threat_detection/rules_engine.dart';
import 'package:netvision_ai/services/threat_detection/threat_classifier.dart';
import 'package:netvision_ai/services/threat_detection/threat_decision_service.dart';
import 'package:netvision_ai/services/threat_features/threat_feature_aggregator.dart';
import 'package:netvision_ai/services/threat_features/threat_feature_window.dart';

class _FakeThreatClassifier implements ThreatClassifier {
  final ThreatClassifierResult result;

  _FakeThreatClassifier(this.result);

  @override
  Future<ThreatClassifierResult> classify(ThreatFeatureWindow window) async =>
      result;
}

void main() {
  final window = ThreatFeatureAggregator().aggregate(
    windowStartUtc: DateTime.utc(2026, 11, 13, 9),
    nodeId: 'node-1',
    serviceId: 'service-1',
    observations: List.generate(
      10,
      (index) => ThreatFlowObservation(
        startedAtUtc:
            DateTime.utc(2026, 11, 13, 9).add(Duration(seconds: index)),
        nodeId: 'node-1',
        serviceId: 'service-1',
        sourceBucket: 'source-$index',
        destinationBucket: 'destination-$index',
        destinationPort: 443,
        protocol: ThreatProtocol.tcp,
        packetsInbound: 1,
        packetsOutbound: 1,
        bytesInbound: 100,
        bytesOutbound: 100,
        tcpFlags: const {},
        durationSeconds: 0.5,
        outcome: ThreatConnectionOutcome.successful,
        requestCount: 1,
        responseCount: 1,
        successfulRequests: 1,
        latencyMs: 20,
        queueSaturation: 0.1,
      ),
    ),
    context: const ThreatWindowContext(capacityProfile: 'medium'),
  );
  const baseline = ThreatRuleBaseline(
    flowStartsPerSecondMean: 10,
    flowStartsPerSecondStdDev: 1,
    failedConnectionRatioMean: 0.01,
    sourceEntropyMean: 4,
    sourceEntropyStdDev: 0.5,
    destinationEntropyMean: 4,
    destinationEntropyStdDev: 0.5,
    errorRateMean: 0,
    successRateMean: 1,
  );

  ThreatDecisionService service(ThreatClassifierResult classifierResult) =>
      ThreatDecisionService(
        rulesEngine: ThreatRulesEngine(),
        classifier: _FakeThreatClassifier(classifierResult),
      );

  test('low-confidence classifier result abstains without a score', () async {
    final assessment = await service(
      ThreatClassifierResult(
        label: ThreatLabel.availabilityAnomaly,
        confidence: 0.4,
        riskWithinForecastHorizon: 0.8,
        outOfDistribution: false,
        modelVersion: 'test-model',
      ),
    ).assess(window: window, baseline: baseline, assessmentId: 'assessment-1');

    expect(assessment.category, ThreatLabel.unknown);
    expect(assessment.confidence, isNull);
    expect(assessment.riskWithinForecastHorizon, isNull);
    expect(assessment.uncertaintyReason, contains('abstention'));
  });

  test('out-of-distribution input abstains even with high confidence',
      () async {
    final assessment = await service(
      ThreatClassifierResult(
        label: ThreatLabel.availabilityAnomaly,
        confidence: 0.99,
        riskWithinForecastHorizon: 0.99,
        outOfDistribution: true,
        modelVersion: 'test-model',
      ),
    ).assess(window: window, baseline: baseline, assessmentId: 'assessment-2');

    expect(assessment.category, ThreatLabel.unknown);
    expect(assessment.confidence, isNull);
    expect(assessment.riskWithinForecastHorizon, isNull);
    expect(assessment.modelVersion, 'test-model');
  });

  test('keeps event confidence and forecast risk as independent outputs',
      () async {
    final assessment = await service(
      ThreatClassifierResult(
        label: ThreatLabel.availabilityAnomaly,
        confidence: 0.82,
        riskWithinForecastHorizon: 0.37,
        outOfDistribution: false,
        modelVersion: 'test-model',
      ),
    ).assess(window: window, baseline: baseline, assessmentId: 'assessment-3');

    expect(assessment.category, ThreatLabel.availabilityAnomaly);
    expect(assessment.confidence, 0.82);
    expect(assessment.riskWithinForecastHorizon, 0.37);
  });
}
