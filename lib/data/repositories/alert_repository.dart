import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import '../models/prediction_model.dart';

class AlertRepository {
  final FirebaseFirestore _firestore;
  static const duplicateSuppressionWindow = Duration(minutes: 5);

  AlertRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream all alerts across all nodes, ordered by createdAt desc.
  /// Optionally filter by status (e.g. only active).
  Stream<List<AlertModel>> watchAlerts({
    AlertStatus? statusFilter,
    int limit = 100,
  }) {
    // Firestore requires a composite index for status + createdAt ordering.
    // The index is already declared in firestore.indexes.json.

    Query query = _firestore.collectionGroup('alerts');

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: _statusId(statusFilter));
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      final alerts = <AlertModel>[];

      // Fetch node names in parallel (small number of unique nodes).
      final nodeIds = snap.docs
          .map((d) =>
              (d.data() as Map<String, dynamic>)['nodeId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final nodeNames = <String, String>{};
      for (final nodeId in nodeIds) {
        final nodeDoc =
            await _firestore.collection('networkNodes').doc(nodeId).get();
        if (nodeDoc.exists) {
          nodeNames[nodeId] =
              (nodeDoc.data() as Map<String, dynamic>)['nodeName'] as String? ??
                  nodeId;
        }
      }

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final nodeId = data['nodeId'] as String? ?? '';
        alerts.add(AlertModel.fromFirestore(doc, nodeName: nodeNames[nodeId]));
      }

      return alerts;
    });
  }

  /// Stream alerts for a specific node.
  Stream<List<AlertModel>> watchAlertsForNode(String nodeId, {int limit = 50}) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => AlertModel.fromFirestore(doc)).toList());
  }

  /// Acknowledge an alert (Network Administrator only).
  Future<void> acknowledgeAlert(
    String nodeId,
    String alertId,
    String userId,
  ) async {
    await _alertRef(nodeId, alertId).update({
      'status': 'Acknowledged',
      'acknowledgedBy': userId,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Dismiss an alert with a required reason.
  Future<void> dismissAlert(
    String nodeId,
    String alertId,
    String userId,
    String reason,
  ) async {
    await _alertRef(nodeId, alertId).update({
      'status': 'Dismissed',
      'acknowledgedBy': userId,
      'dismissalReason': reason,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resolve an alert.
  Future<void> resolveAlert(String nodeId, String alertId) async {
    await _alertRef(nodeId, alertId).update({
      'status': 'Resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> raiseAlertFromPrediction(
    PredictionModel prediction, {
    bool simulation = false,
  }) {
    final message = prediction.message ??
        'BiLSTM fault probability ${prediction.probabilityPercent} '
            'exceeded the alert threshold.';
    return _raiseModelAlert(
      nodeId: prediction.nodeId,
      predictionId: prediction.predictionId,
      severityId: prediction.severity.severityId,
      modelProbability: prediction.faultProbability,
      modelVersionId: prediction.modelVersionId,
      simulation: simulation,
      title: simulation
          ? '[SIMULATION] Predicted fault on ${prediction.nodeId}'
          : 'Predicted fault on ${prediction.nodeId}',
      description: simulation ? '[SIMULATION] $message' : message,
    );
  }

  Future<String?> raiseThreatModelAlert({
    required String assessmentId,
    required String nodeId,
    required String serviceId,
    required String category,
    required double confidence,
    required double? riskWithinForecastHorizon,
    required String modelVersionId,
  }) {
    if (category != 'AVAILABILITY_ANOMALY' && category != 'OPERATIONAL_FAULT') {
      throw ArgumentError.value(
        category,
        'category',
        'only model-detected anomalies can raise alerts',
      );
    }

    final severityId = category == 'AVAILABILITY_ANOMALY' ? 'high' : 'medium';
    final label = category.replaceAll('_', ' ').toLowerCase();
    final riskText = riskWithinForecastHorizon == null
        ? 'unavailable'
        : '${(riskWithinForecastHorizon * 100).toStringAsFixed(1)}%';
    return _raiseModelAlert(
      nodeId: nodeId,
      predictionId: assessmentId,
      severityId: severityId,
      modelProbability: confidence,
      modelVersionId: modelVersionId,
      simulation: true,
      title: '[SIMULATION] Threat model detected $label',
      description: '[SIMULATION] Synthetic cloud model $modelVersionId '
          'detected $label for $serviceId with '
          '${(confidence * 100).toStringAsFixed(1)}% confidence; '
          '10-minute forecast risk: $riskText.',
    );
  }

  Future<String?> _raiseModelAlert({
    required String nodeId,
    required String predictionId,
    required String severityId,
    required double modelProbability,
    required String modelVersionId,
    required bool simulation,
    required String title,
    required String description,
  }) async {
    final recent = await _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('alerts')
        .where('severityId', isEqualTo: severityId)
        .where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(duplicateSuppressionWindow),
          ),
        )
        .limit(20)
        .get();
    if (recent.docs.any((doc) {
      final data = doc.data();
      if (data['status'] != 'Active') return false;
      final isSimulation =
          (data['title'] as String? ?? '').startsWith('[SIMULATION]');
      if (isSimulation != simulation) return false;
      final existingModelVersion = data['modelVersionId'] as String?;
      return existingModelVersion == null ||
          existingModelVersion == modelVersionId;
    })) {
      return null;
    }

    final doc = await _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('alerts')
        .add({
      'nodeId': nodeId,
      'predictionId': predictionId,
      'severityId': severityId,
      'status': 'Active',
      'title': title,
      'description': description,
      'faultProbability': modelProbability,
      'modelVersionId': modelVersionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  DocumentReference<Map<String, dynamic>> _alertRef(
    String nodeId,
    String alertId,
  ) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('alerts')
        .doc(alertId);
  }

  String _statusId(AlertStatus status) {
    switch (status) {
      case AlertStatus.active:
        return 'Active';
      case AlertStatus.acknowledged:
        return 'Acknowledged';
      case AlertStatus.dismissed:
        return 'Dismissed';
      case AlertStatus.resolved:
        return 'Resolved';
    }
  }
}
