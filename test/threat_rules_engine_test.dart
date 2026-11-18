import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/services/threat_detection/rules_engine.dart';
import 'package:netvision_ai/services/threat_features/threat_feature_aggregator.dart';
import 'package:netvision_ai/services/threat_features/threat_feature_window.dart';

void main() {
  final aggregator = ThreatFeatureAggregator();
  final engine = ThreatRulesEngine();
  final start = DateTime.utc(2026, 11, 13, 9);
  const baseline = ThreatRuleBaseline(
    flowStartsPerSecondMean: 1,
    flowStartsPerSecondStdDev: 0.2,
    failedConnectionRatioMean: 0.02,
    sourceEntropyMean: 4,
    sourceEntropyStdDev: 0.5,
    destinationEntropyMean: 3,
    destinationEntropyStdDev: 0.5,
    errorRateMean: 0.01,
    successRateMean: 0.98,
  );

  ThreatFeatureWindow makeWindow({
    int flowCount = 60,
    int failedCount = 0,
    bool concentrated = false,
    int failedRequests = -1,
    int successfulRequests = -1,
  }) {
    final serviceFailures = failedRequests < 0 ? 0 : failedRequests;
    final serviceSuccesses =
        successfulRequests < 0 ? flowCount : successfulRequests;
    final observations = List.generate(flowCount, (index) {
      final isFailed = index < failedCount;
      return ThreatFlowObservation(
        startedAtUtc: start.add(Duration(milliseconds: index * 99)),
        nodeId: 'node-1',
        serviceId: 'service-1',
        sourceBucket: concentrated ? 'shared-source' : 'source-$index',
        destinationBucket:
            concentrated ? 'shared-destination' : 'destination-$index',
        destinationPort: 443,
        protocol: ThreatProtocol.tcp,
        packetsInbound: 1,
        packetsOutbound: 1,
        bytesInbound: 100,
        bytesOutbound: 100,
        tcpFlags: const {},
        durationSeconds: 0.5,
        outcome: isFailed
            ? ThreatConnectionOutcome.failed
            : ThreatConnectionOutcome.successful,
        requestCount: 1,
        responseCount: 1,
        successfulRequests: index < serviceSuccesses ? 1 : 0,
        failedRequests: index >= serviceSuccesses ? 1 : 0,
        latencyMs: 15,
        queueSaturation: 0.1,
      );
    });

    if (serviceFailures + serviceSuccesses != flowCount) {
      throw StateError('Test service counters must match flow count.');
    }

    return aggregator.aggregate(
      windowStartUtc: start,
      nodeId: 'node-1',
      serviceId: 'service-1',
      observations: observations,
      context: const ThreatWindowContext(capacityProfile: 'medium'),
    );
  }

  test(
      'emits distinct availability rules for rate and failed connection spikes',
      () {
    final window = makeWindow(
      flowCount: 600,
      failedCount: 240,
      failedRequests: 0,
      successfulRequests: 600,
    );
    final hits = engine.evaluate(window, baseline);

    expect(hits.map((hit) => hit.ruleId), contains('flow_rate_deviation'));
    expect(hits.map((hit) => hit.ruleId), contains('failed_connection_ratio'));
    expect(
      hits.every((hit) => hit.category == ThreatLabel.availabilityAnomaly),
      isTrue,
    );
  });

  test('corroborates concentration with source entropy collapse', () {
    final window = makeWindow(flowCount: 60, concentrated: true);
    final hits = engine.evaluate(window, baseline);

    expect(hits.map((hit) => hit.ruleId), contains('source_entropy_collapse'));
  });

  test('classifies service errors as an operational fault, not a threat', () {
    final window = makeWindow(
      flowCount: 60,
      failedRequests: 40,
      successfulRequests: 20,
    );
    final hits = engine.evaluate(window, baseline);

    expect(
      hits.single.category,
      ThreatLabel.operationalFault,
    );
    expect(hits.single.ruleId, 'service_health_degradation');
  });

  test('does not make a benign decision from missing telemetry', () {
    final window = aggregator.aggregate(
      windowStartUtc: start,
      nodeId: 'node-1',
      serviceId: 'service-1',
      observations: const [],
      context: const ThreatWindowContext(capacityProfile: 'medium'),
    );

    expect(engine.evaluate(window, baseline), isEmpty);
  });
}
