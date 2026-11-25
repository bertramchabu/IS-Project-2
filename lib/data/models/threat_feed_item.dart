import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/threat_detection/threat_assessment.dart';
import '../../services/threat_detection/threat_classifier.dart';

class ThreatEvidenceLink {
  final String evidenceId;
  final String recordType;

  const ThreatEvidenceLink({
    required this.evidenceId,
    required this.recordType,
  });
}

class ThreatFeedItem {
  final String id;
  final String nodeId;
  final String serviceId;
  final String category;
  final double? confidence;
  final String? uncertaintyReason;
  final DateTime observationStart;
  final DateTime observationEnd;
  final String recommendedAction;
  final bool corroboratedByServiceHealth;
  final String status;
  final DateTime createdAt;
  final List<String> dataQualityFlags;
  final List<Map<String, Object?>> measurements;
  final List<ThreatEvidenceLink> evidenceLinks;
  final ThreatClassifierResult? modelPrediction;
  final bool isSyntheticDemo;

  const ThreatFeedItem({
    required this.id,
    required this.nodeId,
    required this.serviceId,
    required this.category,
    required this.confidence,
    required this.uncertaintyReason,
    required this.observationStart,
    required this.observationEnd,
    required this.recommendedAction,
    required this.corroboratedByServiceHealth,
    required this.status,
    required this.createdAt,
    required this.dataQualityFlags,
    required this.measurements,
    required this.evidenceLinks,
    this.modelPrediction,
    this.isSyntheticDemo = false,
  });

  factory ThreatFeedItem.fromDemoAssessment(ThreatAssessment assessment) {
    return ThreatFeedItem(
      id: assessment.assessmentId,
      nodeId: assessment.nodeId,
      serviceId: assessment.serviceId,
      category: assessment.category.wireValue,
      confidence: assessment.confidence,
      uncertaintyReason: assessment.uncertaintyReason,
      observationStart: assessment.observationStartUtc,
      observationEnd: assessment.observationEndUtc,
      recommendedAction: assessment.recommendedAction.name,
      corroboratedByServiceHealth: assessment.corroboratedByServiceHealth,
      status: 'SIMULATED',
      createdAt: assessment.observationEndUtc,
      dataQualityFlags: [...assessment.dataQualityFlags, 'synthetic_demo'],
      measurements: [
        for (final measurement in assessment.evidence)
          {
            'name': measurement.name,
            'observedValue': measurement.observedValue,
            'baselineValue': measurement.baselineValue,
            'delta': measurement.delta,
            'direction': measurement.direction,
          },
      ],
      evidenceLinks: const [],
      modelPrediction: assessment.modelPrediction,
      isSyntheticDemo: true,
    );
  }

  factory ThreatFeedItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException('Threat assessment ${document.id} has no data.');
    }

    final threatAlert = data['threatAlert'] is Map
        ? Map<String, dynamic>.from(data['threatAlert'] as Map)
        : const <String, dynamic>{};
    final rawLinks = threatAlert['evidenceLinks'] as List<dynamic>? ?? const [];
    final evidenceLinks = rawLinks
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['evidenceId'] is String && item['recordType'] is String)
        .map((item) => ThreatEvidenceLink(
              evidenceId: item['evidenceId'] as String,
              recordType: item['recordType'] as String,
            ))
        .toList();
    return ThreatFeedItem(
      id: document.id,
      nodeId: _requiredString(data, 'nodeId'),
      serviceId: _requiredString(data, 'serviceId'),
      category: _requiredString(data, 'category'),
      confidence: _optionalDouble(data['confidence']),
      uncertaintyReason: data['uncertaintyReason'] as String?,
      observationStart: _dateTime(data['observationStartUtc']),
      observationEnd: _dateTime(data['observationEndUtc']),
      recommendedAction: _requiredString(data, 'recommendedAction'),
      corroboratedByServiceHealth: data['corroboratedByServiceHealth'] == true,
      status: data['status'] as String? ?? 'Open',
      createdAt: _dateTime(data['createdAt']),
      dataQualityFlags: (data['dataQualityFlags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      measurements: (data['evidence'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList(),
      evidenceLinks: evidenceLinks,
    );
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Threat assessment is missing "$key".');
    }
    return value;
  }

  static double? _optionalDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  static DateTime _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.parse(value).toUtc();
    throw const FormatException('Threat assessment timestamp is invalid.');
  }
}
