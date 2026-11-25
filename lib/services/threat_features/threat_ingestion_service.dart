import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/repositories/threat_repository.dart';
import '../threat_detection/rules_engine.dart';
import '../threat_detection/threat_assessment.dart';
import '../threat_detection/threat_decision_service.dart';
import 'threat_feature_aggregator.dart';

class ThreatIngestionService {
  final ThreatFeatureAggregator _aggregator;
  final ThreatDecisionService _decisionService;
  final ThreatRepository _repository;
  final FirebaseFirestore _firestore;

  ThreatIngestionService({
    required ThreatFeatureAggregator aggregator,
    required ThreatDecisionService decisionService,
    required ThreatRepository repository,
    FirebaseFirestore? firestore,
  })  : _aggregator = aggregator,
        _decisionService = decisionService,
        _repository = repository,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<ThreatAssessment> ingest({
    required DateTime windowStartUtc,
    required String nodeId,
    required String serviceId,
    required List<ThreatFlowObservation> observations,
    required ThreatWindowContext context,
    required ThreatRuleBaseline baseline,
    required String thresholdConfigVersion,
  }) async {
    final window = _aggregator.aggregate(
      windowStartUtc: windowStartUtc,
      nodeId: nodeId,
      serviceId: serviceId,
      observations: observations,
      context: context,
    );
    final assessmentId = _firestore.collection('threatAssessments').doc().id;
    final assessment = await _decisionService.assess(
      window: window,
      baseline: baseline,
      assessmentId: assessmentId,
    );
    await _repository.persistAssessment(
      featureWindow: window,
      assessment: assessment,
      thresholdConfigVersion: thresholdConfigVersion,
    );
    return assessment;
  }
}
