import '../threat_features/threat_feature_window.dart';
import 'rules_engine.dart';
import 'threat_classifier.dart';

enum SafeNextStep {
  verifyServiceHealth,
  checkUpstreamMitigationStatus,
  reviewRecentChanges,
  preserveLogs,
  escalateIncident;

  String get label => switch (this) {
        SafeNextStep.verifyServiceHealth => 'Verify service health',
        SafeNextStep.checkUpstreamMitigationStatus =>
          'Check upstream/provider mitigation status',
        SafeNextStep.reviewRecentChanges => 'Review recent changes',
        SafeNextStep.preserveLogs => 'Preserve relevant logs',
        SafeNextStep.escalateIncident =>
          'Escalate through the approved incident process',
      };
}

class ContributingMeasurement {
  final String name;
  final double observedValue;
  final double baselineValue;
  final double delta;
  final String direction;

  const ContributingMeasurement({
    required this.name,
    required this.observedValue,
    required this.baselineValue,
    required this.delta,
    required this.direction,
  });
}

class EvidenceLink {
  final String evidenceId;
  final String recordType;

  const EvidenceLink({
    required this.evidenceId,
    required this.recordType,
  });
}

class ThreatAssessment {
  final String assessmentId;
  final String nodeId;
  final String serviceId;
  final ThreatLabel category;
  final double? confidence;
  final double? riskWithinForecastHorizon;
  final String? uncertaintyReason;
  final DateTime observationStartUtc;
  final DateTime observationEndUtc;
  final List<ThreatRuleHit> ruleHits;
  final List<ContributingMeasurement> evidence;
  final bool corroboratedByServiceHealth;
  final SafeNextStep recommendedAction;
  final String modelVersion;
  final List<String> dataQualityFlags;
  final ThreatClassifierResult? modelPrediction;

  const ThreatAssessment({
    required this.assessmentId,
    required this.nodeId,
    required this.serviceId,
    required this.category,
    required this.confidence,
    required this.riskWithinForecastHorizon,
    required this.uncertaintyReason,
    required this.observationStartUtc,
    required this.observationEndUtc,
    required this.ruleHits,
    required this.evidence,
    required this.corroboratedByServiceHealth,
    required this.recommendedAction,
    required this.modelVersion,
    required this.dataQualityFlags,
    this.modelPrediction,
  });

  bool get isUnknown => category == ThreatLabel.unknown;

  ThreatAssessment withModelPrediction(ThreatClassifierResult prediction) {
    return ThreatAssessment(
      assessmentId: assessmentId,
      nodeId: nodeId,
      serviceId: serviceId,
      category: category,
      confidence: confidence,
      riskWithinForecastHorizon: riskWithinForecastHorizon,
      uncertaintyReason: uncertaintyReason,
      observationStartUtc: observationStartUtc,
      observationEndUtc: observationEndUtc,
      ruleHits: ruleHits,
      evidence: evidence,
      corroboratedByServiceHealth: corroboratedByServiceHealth,
      recommendedAction: recommendedAction,
      modelVersion: modelVersion,
      dataQualityFlags: dataQualityFlags,
      modelPrediction: prediction,
    );
  }

  Map<String, Object?> toMap() => {
        'assessmentId': assessmentId,
        'nodeId': nodeId,
        'serviceId': serviceId,
        'category': category.wireValue,
        'confidence': confidence,
        'riskWithinForecastHorizon': riskWithinForecastHorizon,
        'uncertaintyReason': uncertaintyReason,
        'observationStartUtc': observationStartUtc.toIso8601String(),
        'observationEndUtc': observationEndUtc.toIso8601String(),
        'ruleHits': [
          for (final hit in ruleHits)
            {
              'ruleId': hit.ruleId,
              'severity': hit.severity.name,
              'evidence': hit.evidence,
              'threshold': hit.threshold,
              'observedValue': hit.observedValue,
              'category': hit.category.wireValue,
            },
        ],
        'evidence': [
          for (final measurement in evidence)
            {
              'name': measurement.name,
              'observedValue': measurement.observedValue,
              'baselineValue': measurement.baselineValue,
              'delta': measurement.delta,
              'direction': measurement.direction,
            },
        ],
        'corroboratedByServiceHealth': corroboratedByServiceHealth,
        'recommendedAction': recommendedAction.name,
        'modelVersion': modelVersion,
        'dataQualityFlags': dataQualityFlags,
        if (modelPrediction != null)
          'modelPrediction': {
            'category': modelPrediction!.label.wireValue,
            'confidence': modelPrediction!.confidence,
            'riskWithinForecastHorizon':
                modelPrediction!.riskWithinForecastHorizon,
            'outOfDistribution': modelPrediction!.outOfDistribution,
            'uncertaintyReason': modelPrediction!.uncertaintyReason,
            'modelVersion': modelPrediction!.modelVersion,
          },
      };
}

class ThreatAlert {
  final String category;
  final double? confidence;
  final String? uncertaintyReason;
  final String affectedNodeOrService;
  final DateTime observationStart;
  final DateTime observationEnd;
  final List<ContributingMeasurement> evidence;
  final bool corroboratedByServiceHealth;
  final SafeNextStep recommendedAction;
  final List<EvidenceLink> evidenceLinks;

  const ThreatAlert({
    required this.category,
    required this.confidence,
    required this.uncertaintyReason,
    required this.affectedNodeOrService,
    required this.observationStart,
    required this.observationEnd,
    required this.evidence,
    required this.corroboratedByServiceHealth,
    required this.recommendedAction,
    required this.evidenceLinks,
  });

  factory ThreatAlert.fromAssessment(
    ThreatAssessment assessment, {
    List<EvidenceLink> evidenceLinks = const [],
  }) {
    return ThreatAlert(
      category: assessment.category.wireValue,
      confidence: assessment.confidence,
      uncertaintyReason: assessment.uncertaintyReason,
      affectedNodeOrService: '${assessment.nodeId}/${assessment.serviceId}',
      observationStart: assessment.observationStartUtc,
      observationEnd: assessment.observationEndUtc,
      evidence: assessment.evidence,
      corroboratedByServiceHealth: assessment.corroboratedByServiceHealth,
      recommendedAction: assessment.recommendedAction,
      evidenceLinks: evidenceLinks,
    );
  }
}
