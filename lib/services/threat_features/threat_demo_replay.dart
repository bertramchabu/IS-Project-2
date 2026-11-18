import '../threat_detection/rules_engine.dart';
import '../threat_detection/threat_assessment.dart';
import '../threat_detection/threat_classifier.dart';
import '../threat_detection/threat_decision_service.dart';
import 'threat_feature_aggregator.dart';
import 'threat_feature_window.dart';

class ThreatDemoResult {
  final ThreatFeatureWindow featureWindow;
  final ThreatAssessment assessment;

  const ThreatDemoResult({
    required this.featureWindow,
    required this.assessment,
  });
}

class ThreatDemoReplay {
  static const demoNodeId = 'SYNTHETIC-DEMO-NODE';
  static const demoServiceId = 'synthetic-edge-service';

  static const _baseline = ThreatRuleBaseline(
    flowStartsPerSecondMean: 1,
    flowStartsPerSecondStdDev: 0.2,
    failedConnectionRatioMean: 0.05,
    sourceEntropyMean: 3,
    sourceEntropyStdDev: 0.2,
    destinationEntropyMean: 3,
    destinationEntropyStdDev: 0.2,
    errorRateMean: 0.02,
    successRateMean: 0.98,
  );

  final ThreatFeatureAggregator _aggregator;
  final ThreatDecisionService _decisionService;
  final ThreatClassifier _modelClassifier;

  ThreatDemoReplay({
    ThreatFeatureAggregator? aggregator,
    ThreatDecisionService? decisionService,
    ThreatClassifier? modelClassifier,
  })  : _aggregator = aggregator ?? ThreatFeatureAggregator(),
        _modelClassifier =
            modelClassifier ?? const UnavailableThreatClassifier(),
        _decisionService = decisionService ??
            ThreatDecisionService(
              rulesEngine: ThreatRulesEngine(),
              classifier: const UnavailableThreatClassifier(),
            );

  Future<List<ThreatDemoResult>> generate() async {
    final now = DateTime.now().toUtc();
    final replayId = now.microsecondsSinceEpoch;
    final currentMinute =
        DateTime.utc(now.year, now.month, now.day, now.hour, now.minute);
    final firstWindow = currentMinute.subtract(const Duration(minutes: 3));
    const scenarios = [
      (name: 'baseline', flowCount: 12, mode: _DemoMode.normal),
      (name: 'availability', flowCount: 120, mode: _DemoMode.availability),
      (name: 'operations', flowCount: 12, mode: _DemoMode.operationalFault),
    ];
    final results = <ThreatDemoResult>[];

    for (var index = 0; index < scenarios.length; index++) {
      final scenario = scenarios[index];
      final windowStart = firstWindow.add(Duration(minutes: index)).toUtc();
      final window = _aggregator.aggregate(
        windowStartUtc: windowStart,
        nodeId: demoNodeId,
        serviceId: demoServiceId,
        observations: _observations(
          mode: scenario.mode,
          count: scenario.flowCount,
          windowStartUtc: windowStart,
        ),
        context: const ThreatWindowContext(
          capacityProfile: 'synthetic-demo',
          isSyntheticDemo: true,
        ),
      );
      final assessment = await _decisionService.assess(
        window: window,
        baseline: _baseline,
        assessmentId:
            'demo-$replayId-${scenario.name}-${windowStart.microsecondsSinceEpoch}',
      );
      final modelPrediction = await _modelClassifier.classify(window);
      results.add(ThreatDemoResult(
        featureWindow: window,
        assessment: assessment.withModelPrediction(modelPrediction),
      ));
    }

    return results;
  }

  List<ThreatFlowObservation> _observations({
    required _DemoMode mode,
    required int count,
    required DateTime windowStartUtc,
  }) {
    return List.generate(count, (index) {
      final isAvailability = mode == _DemoMode.availability;
      final isOperationalFault = mode == _DemoMode.operationalFault;
      final failedConnection = isAvailability && index % 2 == 0;
      final successfulRequests = isOperationalFault ? 2 : 10;
      final failedRequests = isOperationalFault ? 8 : 0;

      return ThreatFlowObservation(
        startedAtUtc: windowStartUtc
            .add(Duration(microseconds: (index * 60000000 / count).floor()))
            .toUtc(),
        nodeId: demoNodeId,
        serviceId: demoServiceId,
        sourceBucket:
            isAvailability ? 'synthetic-source-${index % 2}' : 'source-$index',
        destinationBucket:
            isAvailability ? 'synthetic-destination' : 'destination-$index',
        destinationPort: 443,
        protocol: ThreatProtocol.tcp,
        packetsInbound: 8,
        packetsOutbound: 5,
        bytesInbound: 1200,
        bytesOutbound: 800,
        tcpFlags: const {'SYN': 1, 'ACK': 1},
        durationSeconds: 2,
        outcome: failedConnection
            ? ThreatConnectionOutcome.failed
            : ThreatConnectionOutcome.successful,
        requestCount: 10,
        responseCount: successfulRequests,
        successfulRequests: successfulRequests,
        failedRequests: failedRequests,
        latencyMs: isOperationalFault ? 650 : 45,
        queueSaturation: isOperationalFault ? 0.95 : 0.12,
      );
    });
  }
}

enum _DemoMode { normal, availability, operationalFault }
