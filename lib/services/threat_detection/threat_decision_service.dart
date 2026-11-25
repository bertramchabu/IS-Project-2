import '../threat_features/threat_feature_window.dart';
import 'rules_engine.dart';
import 'threat_assessment.dart';
import 'threat_classifier.dart';

class ThreatDecisionService {
  final ThreatRulesEngine _rulesEngine;
  final ThreatClassifier _classifier;
  final double abstainThreshold;

  ThreatDecisionService({
    required ThreatRulesEngine rulesEngine,
    required ThreatClassifier classifier,
    this.abstainThreshold = 0.60,
  })  : _rulesEngine = rulesEngine,
        _classifier = classifier {
    if (!abstainThreshold.isFinite ||
        abstainThreshold < 0 ||
        abstainThreshold > 1) {
      throw ArgumentError('abstainThreshold must be in 0..1.');
    }
  }

  Future<ThreatAssessment> assess({
    required ThreatFeatureWindow window,
    required ThreatRuleBaseline baseline,
    required String assessmentId,
  }) async {
    if (assessmentId.trim().isEmpty) {
      throw ArgumentError('assessmentId must not be empty.');
    }
    final hits = _rulesEngine.evaluate(window, baseline);
    final categories = hits.map((hit) => hit.category).toSet();
    if (categories.length == 1) {
      final category = categories.single;
      final measurement = _ruleMeasurement(hits);
      return ThreatAssessment(
        assessmentId: assessmentId,
        nodeId: window.nodeId,
        serviceId: window.serviceId,
        category: category,
        confidence: null,
        riskWithinForecastHorizon: null,
        uncertaintyReason:
            'Rule-based decision; no calibrated model confidence or forecast was used.',
        observationStartUtc: window.windowStartUtc,
        observationEndUtc: window.windowEndUtc,
        ruleHits: hits,
        evidence: measurement,
        corroboratedByServiceHealth: _serviceHealthCorroborated(window),
        recommendedAction: _recommendedAction(category),
        modelVersion: 'rules-v1',
        dataQualityFlags: window.dataQualityFlags,
      );
    }

    if (categories.length > 1) {
      return _unknownAssessment(
        assessmentId,
        window,
        hits,
        'Conflicting operational and availability rules fired.',
      );
    }
    if (!window.isSuitableForClassification) {
      return _unknownAssessment(
        assessmentId,
        window,
        hits,
        'Input window failed data-quality checks.',
      );
    }

    final result = await _classifier.classify(window);
    if (result.outOfDistribution) {
      return _unknownAssessment(
        assessmentId,
        window,
        hits,
        result.uncertaintyReason ??
            'Input is out of the model training domain.',
        modelVersion: result.modelVersion,
      );
    }
    if (result.label == ThreatLabel.unknown ||
        result.confidence < abstainThreshold) {
      return _unknownAssessment(
        assessmentId,
        window,
        hits,
        result.uncertaintyReason ??
            'Model confidence did not meet the abstention threshold.',
        modelVersion: result.modelVersion,
      );
    }

    return ThreatAssessment(
      assessmentId: assessmentId,
      nodeId: window.nodeId,
      serviceId: window.serviceId,
      category: result.label,
      confidence: result.confidence,
      riskWithinForecastHorizon: result.riskWithinForecastHorizon,
      uncertaintyReason: null,
      observationStartUtc: window.windowStartUtc,
      observationEndUtc: window.windowEndUtc,
      ruleHits: hits,
      evidence: const [],
      corroboratedByServiceHealth: _serviceHealthCorroborated(window),
      recommendedAction: _recommendedAction(result.label),
      modelVersion: result.modelVersion,
      dataQualityFlags: window.dataQualityFlags,
    );
  }

  ThreatAssessment _unknownAssessment(
    String assessmentId,
    ThreatFeatureWindow window,
    List<ThreatRuleHit> hits,
    String reason, {
    String modelVersion = 'unavailable',
  }) {
    return ThreatAssessment(
      assessmentId: assessmentId,
      nodeId: window.nodeId,
      serviceId: window.serviceId,
      category: ThreatLabel.unknown,
      confidence: null,
      riskWithinForecastHorizon: null,
      uncertaintyReason: reason,
      observationStartUtc: window.windowStartUtc,
      observationEndUtc: window.windowEndUtc,
      ruleHits: hits,
      evidence: _ruleMeasurement(hits),
      corroboratedByServiceHealth: _serviceHealthCorroborated(window),
      recommendedAction: SafeNextStep.verifyServiceHealth,
      modelVersion: modelVersion,
      dataQualityFlags: window.dataQualityFlags,
    );
  }

  List<ContributingMeasurement> _ruleMeasurement(List<ThreatRuleHit> hits) {
    return [
      for (final hit in hits)
        ContributingMeasurement(
          name: hit.ruleId,
          observedValue: hit.observedValue,
          baselineValue: hit.threshold,
          delta: hit.observedValue - hit.threshold,
          direction:
              hit.observedValue >= hit.threshold ? 'increased' : 'decreased',
        ),
    ];
  }

  bool _serviceHealthCorroborated(ThreatFeatureWindow window) =>
      window.errorRate > 0.2 ||
      window.timeoutRate > 0.2 ||
      window.queueSaturation > 0.9;

  SafeNextStep _recommendedAction(ThreatLabel label) => switch (label) {
        ThreatLabel.benign => SafeNextStep.verifyServiceHealth,
        ThreatLabel.availabilityAnomaly =>
          SafeNextStep.checkUpstreamMitigationStatus,
        ThreatLabel.operationalFault => SafeNextStep.reviewRecentChanges,
        ThreatLabel.unknown => SafeNextStep.verifyServiceHealth,
      };
}
