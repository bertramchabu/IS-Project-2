import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/threat_feed_item.dart';
import '../../services/threat_detection/threat_assessment.dart';
import '../../services/threat_features/threat_feature_window.dart';

class ThreatEvidenceRecord {
  final String id;
  final String recordType;
  final String resourceId;
  final String payloadJson;
  final String payloadHashSha256;
  final DateTime timestampUtc;
  final DateTime? ingestionTimeUtc;

  const ThreatEvidenceRecord({
    required this.id,
    required this.recordType,
    required this.resourceId,
    required this.payloadJson,
    required this.payloadHashSha256,
    required this.timestampUtc,
    required this.ingestionTimeUtc,
  });

  bool get hashIsValid =>
      sha256.convert(utf8.encode(payloadJson)).toString() == payloadHashSha256;

  factory ThreatEvidenceRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException('Evidence record ${document.id} has no data.');
    }
    return ThreatEvidenceRecord(
      id: document.id,
      recordType: _string(data, 'recordType'),
      resourceId: _string(data, 'resourceId'),
      payloadJson: _string(data, 'payloadJson'),
      payloadHashSha256: _string(data, 'payloadHashSha256'),
      timestampUtc: _dateTime(data['timestampUtc']),
      ingestionTimeUtc: data['ingestionTimeUtc'] == null
          ? null
          : _dateTime(data['ingestionTimeUtc']),
    );
  }

  static String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Evidence record is missing "$key".');
    }
    return value;
  }

  static DateTime _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is String) return DateTime.parse(value).toUtc();
    throw const FormatException('Evidence timestamp is invalid.');
  }
}

class ThreatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ThreatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _assessments =>
      _firestore.collection('threatAssessments');
  CollectionReference<Map<String, dynamic>> get _featureWindows =>
      _firestore.collection('threatFeatureWindows');
  CollectionReference<Map<String, dynamic>> get _evidence =>
      _firestore.collection('forensicEvidence');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _firestore.collection('auditLogs');

  Future<String> persistAssessment({
    required ThreatFeatureWindow featureWindow,
    required ThreatAssessment assessment,
    required String thresholdConfigVersion,
  }) async {
    final user = _requireUser();
    if (assessment.assessmentId.trim().isEmpty ||
        assessment.assessmentId.contains('/')) {
      throw ArgumentError('assessmentId must be a non-empty document ID.');
    }
    if (assessment.nodeId != featureWindow.nodeId ||
        assessment.serviceId != featureWindow.serviceId ||
        assessment.observationStartUtc != featureWindow.windowStartUtc ||
        assessment.observationEndUtc != featureWindow.windowEndUtc) {
      throw ArgumentError(
        'Assessment identity and observation interval must match its features.',
      );
    }
    if (thresholdConfigVersion.trim().isEmpty) {
      throw ArgumentError('thresholdConfigVersion must not be empty.');
    }

    final assessmentRef = _assessments.doc(assessment.assessmentId);
    final evidenceRef = _evidence.doc();
    final featureRef = _featureWindows.doc();
    final assessmentPayload = <String, Object?>{
      ...assessment.toMap(),
      'featureWindow': featureWindow.toMap(),
      'thresholdConfigVersion': thresholdConfigVersion,
      'status':
          assessment.category == ThreatLabel.benign ? 'NotApplicable' : 'Open',
      'createdBy': user.uid,
    };
    final alert = ThreatAlert.fromAssessment(
      assessment,
      evidenceLinks: [
        EvidenceLink(
          evidenceId: evidenceRef.id,
          recordType: 'threat_inference',
        ),
      ],
    );
    assessmentPayload['threatAlert'] = {
      'category': alert.category,
      'confidence': alert.confidence,
      'uncertaintyReason': alert.uncertaintyReason,
      'affectedNodeOrService': alert.affectedNodeOrService,
      'observationStart': alert.observationStart.toIso8601String(),
      'observationEnd': alert.observationEnd.toIso8601String(),
      'corroboratedByServiceHealth': alert.corroboratedByServiceHealth,
      'recommendedAction': alert.recommendedAction.name,
      'evidenceLinks': [
        for (final link in alert.evidenceLinks)
          {'evidenceId': link.evidenceId, 'recordType': link.recordType},
      ],
    };

    final evidencePayload = <String, Object?>{
      'recordType': 'threat_inference',
      'timestampUtc': featureWindow.windowEndUtc.toIso8601String(),
      'actorUserId': user.uid,
      'resourceId': assessmentRef.id,
      'featureWindow': featureWindow.toMap(),
      'assessment': assessmentPayload,
      'modelVersion': assessment.modelVersion,
      'scalerVersion': 'not_applicable',
      'thresholdConfigVersion': thresholdConfigVersion,
      'dataQualityFlags': featureWindow.dataQualityFlags,
    };
    final canonicalJson = jsonEncode(_canonicalize(evidencePayload));
    final payloadHash = sha256.convert(utf8.encode(canonicalJson)).toString();

    final batch = _firestore.batch();
    batch.set(assessmentRef, {
      ...assessmentPayload,
      'createdAt': FieldValue.serverTimestamp(),
      'featureWindowId': featureRef.id,
      'evidenceId': evidenceRef.id,
    });
    batch.set(featureRef, {
      ...featureWindow.toMap(),
      'sourceTimestampUtc': Timestamp.fromDate(featureWindow.windowEndUtc),
      'ingestionTimeUtc': FieldValue.serverTimestamp(),
      'assessmentId': assessmentRef.id,
    });
    batch.set(evidenceRef, {
      'recordType': 'threat_inference',
      'timestampUtc': Timestamp.fromDate(featureWindow.windowEndUtc),
      'ingestionTimeUtc': FieldValue.serverTimestamp(),
      'actorUserId': user.uid,
      'resourceId': assessmentRef.id,
      'payloadJson': canonicalJson,
      'payloadHashSha256': payloadHash,
      'modelVersion': assessment.modelVersion,
      'scalerVersion': 'not_applicable',
      'thresholdConfigVersion': thresholdConfigVersion,
      'dataQualityFlags': featureWindow.dataQualityFlags,
    });
    batch.set(_audit.doc(), {
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? user.uid,
      'action': 'THREAT_ASSESSMENT_CREATED',
      'details':
          'assessmentId=${assessmentRef.id}; category=${assessment.category.wireValue}',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return assessmentRef.id;
  }

  Stream<List<ThreatFeedItem>> watchAssessments({
    String? nodeId,
    int limit = 100,
  }) {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'must be from 1 to 500');
    }
    final user = _requireUser();
    Query<Map<String, dynamic>> query = _assessments;
    if (nodeId != null && nodeId.isNotEmpty) {
      query = query.where('nodeId', isEqualTo: nodeId);
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
    return Stream.fromFuture(
      _writeAudit(
        user,
        'THREAT_ASSESSMENTS_READ',
        nodeId == null ? 'All threat assessments' : 'nodeId=$nodeId',
      ),
    ).asyncExpand((_) => query.snapshots().map((snapshot) =>
        snapshot.docs.map(ThreatFeedItem.fromFirestore).toList()));
  }

  Future<void> recordLifecycleEvent({
    required String assessmentId,
    required String eventType,
    required String details,
    String? nextStatus,
  }) async {
    const allowedEvents = {
      'acknowledged',
      'dismissed',
      'resolved',
      'recommendation_displayed',
      'recommendation_actioned',
    };
    if (!allowedEvents.contains(eventType)) {
      throw ArgumentError.value(eventType, 'eventType', 'is not supported');
    }
    final requiredStatus = switch (eventType) {
      'acknowledged' => 'Acknowledged',
      'dismissed' => 'Dismissed',
      'resolved' => 'Resolved',
      _ => null,
    };
    if (requiredStatus != nextStatus) {
      throw ArgumentError(
        'The lifecycle status must match the event type.',
      );
    }
    final user = _requireUser();
    final assessmentRef = _assessments.doc(assessmentId);
    final snapshot = await assessmentRef.get();
    if (!snapshot.exists) {
      throw StateError('Threat assessment $assessmentId does not exist.');
    }

    final timestampUtc = DateTime.now().toUtc();
    final payload = <String, Object?>{
      'recordType': 'alert_event',
      'eventType': eventType,
      'timestampUtc': timestampUtc.toIso8601String(),
      'actorUserId': user.uid,
      'resourceId': assessmentId,
      'details': details,
      if (nextStatus != null) 'nextStatus': nextStatus,
    };
    final canonicalJson = jsonEncode(_canonicalize(payload));
    final evidenceRef = _evidence.doc();
    final auditRef = _audit.doc();
    final batch = _firestore.batch();
    if (nextStatus != null) {
      batch.update(assessmentRef, {
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(evidenceRef, {
      'recordType': 'alert_event',
      'timestampUtc': Timestamp.fromDate(timestampUtc),
      'ingestionTimeUtc': FieldValue.serverTimestamp(),
      'actorUserId': user.uid,
      'resourceId': assessmentId,
      'payloadJson': canonicalJson,
      'payloadHashSha256':
          sha256.convert(utf8.encode(canonicalJson)).toString(),
      'modelVersion':
          (snapshot.data()?['modelVersion'] as String?) ?? 'unknown',
      'scalerVersion': 'not_applicable',
      'thresholdConfigVersion':
          (snapshot.data()?['thresholdConfigVersion'] as String?) ?? 'unknown',
      'dataQualityFlags':
          (snapshot.data()?['dataQualityFlags'] as List<dynamic>?) ?? const [],
    });
    batch.set(auditRef, {
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? user.uid,
      'action': 'THREAT_${eventType.toUpperCase()}',
      'details': 'assessmentId=$assessmentId; $details',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<List<ThreatEvidenceRecord>> watchEvidence(String assessmentId) {
    final user = _requireUser();
    final query = _evidence
        .where('resourceId', isEqualTo: assessmentId)
        .orderBy('timestampUtc');
    return Stream.fromFuture(
      _writeAudit(user, 'THREAT_EVIDENCE_READ', 'assessmentId=$assessmentId'),
    ).asyncExpand((_) => query.snapshots().map((snapshot) =>
        snapshot.docs.map(ThreatEvidenceRecord.fromFirestore).toList()));
  }

  Future<List<ThreatEvidenceRecord>> exportEvidence(
    String assessmentId,
  ) async {
    final user = _requireUser();
    final snapshot = await _evidence
        .where('resourceId', isEqualTo: assessmentId)
        .orderBy('timestampUtc')
        .get();
    final records =
        snapshot.docs.map(ThreatEvidenceRecord.fromFirestore).toList();
    final invalid = records.where((record) => !record.hashIsValid).toList();
    if (invalid.isNotEmpty) {
      throw StateError(
        'Evidence integrity verification failed for ${invalid.length} record(s).',
      );
    }
    await _writeAudit(
      user,
      'THREAT_EVIDENCE_EXPORTED',
      'assessmentId=$assessmentId; recordCount=${records.length}',
    );
    return records;
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to access threat monitoring.');
    return user;
  }

  Future<void> _writeAudit(User user, String action, String details) async {
    await _audit.add({
      'userId': user.uid,
      'userName': user.displayName ?? user.email ?? user.uid,
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }
}
