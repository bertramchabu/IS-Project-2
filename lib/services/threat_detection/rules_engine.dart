import '../threat_features/threat_feature_window.dart';

enum ThreatRuleSeverity { informational, warning, high }

class ThreatRuleHit {
  final String ruleId;
  final ThreatRuleSeverity severity;
  final String evidence;
  final double threshold;
  final double observedValue;
  final ThreatLabel category;

  const ThreatRuleHit({
    required this.ruleId,
    required this.severity,
    required this.evidence,
    required this.threshold,
    required this.observedValue,
    required this.category,
  });
}

class ThreatRuleBaseline {
  final double flowStartsPerSecondMean;
  final double flowStartsPerSecondStdDev;
  final double failedConnectionRatioMean;
  final double sourceEntropyMean;
  final double sourceEntropyStdDev;
  final double destinationEntropyMean;
  final double destinationEntropyStdDev;
  final double errorRateMean;
  final double successRateMean;

  const ThreatRuleBaseline({
    required this.flowStartsPerSecondMean,
    required this.flowStartsPerSecondStdDev,
    required this.failedConnectionRatioMean,
    required this.sourceEntropyMean,
    required this.sourceEntropyStdDev,
    required this.destinationEntropyMean,
    required this.destinationEntropyStdDev,
    required this.errorRateMean,
    required this.successRateMean,
  });
}

class ThreatRulesEngine {
  static const _standardDeviationMultiplier = 3.0;
  static const _minimumFailedConnectionIncrease = 0.20;
  static const _concentratedDestinationShare = 0.80;
  static const _minimumServiceErrorIncrease = 0.20;
  static const _minimumSuccessRateDrop = 0.20;

  List<ThreatRuleHit> evaluate(
    ThreatFeatureWindow window,
    ThreatRuleBaseline baseline,
  ) {
    _validateBaseline(baseline);
    if (window.dataQualityFlags.contains('no_flow_observations') ||
        window.dataQualityFlags.contains('clock_offset_exceeds_tolerance') ||
        window.dataQualityFlags.contains('out_of_order_observations') ||
        window.dataQualityFlags.contains('service_outcome_counts_mismatch')) {
      return const [];
    }

    final hits = <ThreatRuleHit>[];
    final flowRate = window.rates['flow_starts_per_sec'];
    if (flowRate != null) {
      final threshold = baseline.flowStartsPerSecondMean +
          _standardDeviationMultiplier * baseline.flowStartsPerSecondStdDev;
      if (flowRate > threshold) {
        hits.add(ThreatRuleHit(
          ruleId: 'flow_rate_deviation',
          severity: ThreatRuleSeverity.high,
          evidence: 'Flow-start rate exceeded its node baseline by 3 SD.',
          threshold: threshold,
          observedValue: flowRate,
          category: ThreatLabel.availabilityAnomaly,
        ));
      }
    }

    final failedRatio = window.totalConnections == 0
        ? 0.0
        : window.failedConnections / window.totalConnections;
    final failedThreshold =
        baseline.failedConnectionRatioMean + _minimumFailedConnectionIncrease;
    if (failedRatio > failedThreshold) {
      hits.add(ThreatRuleHit(
        ruleId: 'failed_connection_ratio',
        severity: ThreatRuleSeverity.warning,
        evidence: 'Failed-connection ratio rose above its node baseline.',
        threshold: failedThreshold,
        observedValue: failedRatio,
        category: ThreatLabel.availabilityAnomaly,
      ));
    }

    final sourceThreshold = baseline.sourceEntropyMean -
        _standardDeviationMultiplier * baseline.sourceEntropyStdDev;
    if (window.sourceAddressEntropy < sourceThreshold &&
        window.topDestinationShare > _concentratedDestinationShare) {
      hits.add(ThreatRuleHit(
        ruleId: 'source_entropy_collapse',
        severity: ThreatRuleSeverity.warning,
        evidence:
            'Source diversity collapsed while destination concentration increased.',
        threshold: sourceThreshold,
        observedValue: window.sourceAddressEntropy,
        category: ThreatLabel.availabilityAnomaly,
      ));
    }

    final destinationThreshold = baseline.destinationEntropyMean -
        _standardDeviationMultiplier * baseline.destinationEntropyStdDev;
    if (window.destinationAddressEntropy < destinationThreshold &&
        window.topDestinationShare > _concentratedDestinationShare) {
      hits.add(ThreatRuleHit(
        ruleId: 'destination_entropy_collapse',
        severity: ThreatRuleSeverity.warning,
        evidence:
            'Destination diversity collapsed while destination concentration increased.',
        threshold: destinationThreshold,
        observedValue: window.destinationAddressEntropy,
        category: ThreatLabel.availabilityAnomaly,
      ));
    }

    if (window.errorRate >
            baseline.errorRateMean + _minimumServiceErrorIncrease &&
        window.successRate <
            baseline.successRateMean - _minimumSuccessRateDrop) {
      hits.add(ThreatRuleHit(
        ruleId: 'service_health_degradation',
        severity: ThreatRuleSeverity.warning,
        evidence:
            'Service errors increased while successful requests decreased.',
        threshold: baseline.errorRateMean + _minimumServiceErrorIncrease,
        observedValue: window.errorRate,
        category: ThreatLabel.operationalFault,
      ));
    }
    return hits;
  }

  void _validateBaseline(ThreatRuleBaseline baseline) {
    final values = [
      baseline.flowStartsPerSecondMean,
      baseline.flowStartsPerSecondStdDev,
      baseline.failedConnectionRatioMean,
      baseline.sourceEntropyMean,
      baseline.sourceEntropyStdDev,
      baseline.destinationEntropyMean,
      baseline.destinationEntropyStdDev,
      baseline.errorRateMean,
      baseline.successRateMean,
    ];
    if (values.any((value) => !value.isFinite || value < 0) ||
        baseline.failedConnectionRatioMean > 1 ||
        baseline.errorRateMean > 1 ||
        baseline.successRateMean > 1) {
      throw ArgumentError('Threat rule baseline contains invalid values.');
    }
  }
}
