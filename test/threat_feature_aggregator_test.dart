import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/services/threat_features/threat_feature_aggregator.dart';
import 'package:netvision_ai/services/threat_features/threat_feature_window.dart';

void main() {
  final aggregator = ThreatFeatureAggregator();
  final start = DateTime.utc(2026, 11, 13, 9);

  ThreatFlowObservation flow({
    required int index,
    String source = 'source-a',
    String destination = 'destination-a',
    ThreatProtocol protocol = ThreatProtocol.tcp,
    ThreatConnectionOutcome outcome = ThreatConnectionOutcome.successful,
    int port = 443,
    int bytesIn = 120,
    int bytesOut = 80,
  }) {
    return ThreatFlowObservation(
      startedAtUtc: start.add(Duration(seconds: index)),
      nodeId: 'node-1',
      serviceId: 'service-1',
      sourceBucket: source,
      destinationBucket: destination,
      destinationPort: port,
      protocol: protocol,
      packetsInbound: 2,
      packetsOutbound: 3,
      bytesInbound: bytesIn,
      bytesOutbound: bytesOut,
      tcpFlags: const {'syn': 1, 'ack': 1},
      durationSeconds: 2,
      outcome: outcome,
      requestCount: 1,
      responseCount: 1,
      successfulRequests: outcome == ThreatConnectionOutcome.successful ? 1 : 0,
      failedRequests: outcome == ThreatConnectionOutcome.failed ? 1 : 0,
      timedOutRequests: outcome == ThreatConnectionOutcome.incomplete ? 1 : 0,
      latencyMs: 20 + index.toDouble(),
      queueSaturation: 0.25,
    );
  }

  ThreatFeatureWindow collect(List<ThreatFlowObservation> observations) =>
      aggregator.aggregate(
        windowStartUtc: start,
        nodeId: 'node-1',
        serviceId: 'service-1',
        observations: observations,
        context: const ThreatWindowContext(capacityProfile: 'medium'),
      );

  test('aggregates a UTC-aligned minute without retaining bucket values', () {
    final window = collect([
      flow(index: 0, protocol: ThreatProtocol.tcp),
      flow(
        index: 1,
        source: 'source-b',
        destination: 'destination-b',
        protocol: ThreatProtocol.udp,
        bytesIn: 40,
        bytesOut: 60,
      ),
    ]);

    expect(window.windowEndUtc, start.add(const Duration(seconds: 60)));
    expect(window.rates['flow_starts_per_sec'], 2 / 60);
    expect(window.rates['packets_per_sec'], 10 / 60);
    expect(window.protocolProportions['tcp'], 0.5);
    expect(window.destinationPortCounts, {'443': 2});
    expect(window.sourceAddressEntropy, 1);
    expect(window.topDestinationShare, 0.5);
    expect(window.p95LatencyMs, 21);
    expect(window.dataQualityFlags, isEmpty);
    expect(window.toMap()['schemaVersion'], ThreatFeatureWindow.schemaVersion);
    expect(window.toMap().containsKey('sourceBucket'), isFalse);
    expect(window.tcpFlagCounts.keys, containsAll(['SYN', 'ACK']));
  });

  test('bounds destination port aggregates to the ten most frequent ports', () {
    final window = collect([
      for (var index = 0; index < 12; index++)
        flow(index: index, port: 1000 + index),
    ]);

    expect(window.destinationPortCounts, hasLength(10));
  });

  test('marks out-of-order timestamps and excessive clock offset', () {
    final window = collect([
      flow(index: 3),
      flow(index: 1),
    ]);
    final clockSkewed = aggregator.aggregate(
      windowStartUtc: start,
      nodeId: 'node-1',
      serviceId: 'service-1',
      observations: [flow(index: 1)],
      context: const ThreatWindowContext(
        capacityProfile: 'medium',
        observedClockOffset: Duration(seconds: 5),
      ),
    );

    expect(window.dataQualityFlags, contains('out_of_order_observations'));
    expect(window.isSuitableForClassification, isFalse);
    expect(
      clockSkewed.dataQualityFlags,
      contains('clock_offset_exceeds_tolerance'),
    );
  });

  test('flags absent data instead of treating it as benign traffic', () {
    final window = collect(const []);

    expect(window.dataQualityFlags, contains('no_flow_observations'));
    expect(window.isSuitableForClassification, isFalse);
  });

  test('rejects local timestamps and non-minute window boundaries', () {
    expect(
      () => aggregator.aggregate(
        windowStartUtc: DateTime(2026, 11, 13, 9),
        nodeId: 'node-1',
        serviceId: 'service-1',
        observations: const [],
        context: const ThreatWindowContext(capacityProfile: 'medium'),
      ),
      throwsArgumentError,
    );
    expect(
      () => aggregator.aggregate(
        windowStartUtc: start.add(const Duration(seconds: 1)),
        nodeId: 'node-1',
        serviceId: 'service-1',
        observations: const [],
        context: const ThreatWindowContext(capacityProfile: 'medium'),
      ),
      throwsArgumentError,
    );
  });
}
