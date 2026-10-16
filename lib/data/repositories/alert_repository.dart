import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';

class AlertRepository {
  final FirebaseFirestore _firestore;

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
          .map((d) => (d.data() as Map<String, dynamic>)['nodeId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final nodeNames = <String, String>{};
      for (final nodeId in nodeIds) {
        final nodeDoc = await _firestore
            .collection('networkNodes')
            .doc(nodeId)
            .get();
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
  Stream<List<AlertModel>> watchAlertsForNode(String nodeId,
      {int limit = 50}) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AlertModel.fromFirestore(doc))
            .toList());
  }

  /// Acknowledge an alert (Network Administrator only).
  Future<void> acknowledgeAlert(String alertId, String userId) async {
    final alertRef = await _findAlertRef(alertId);
    if (alertRef == null) {
      throw Exception('Alert not found: $alertId');
    }

    await alertRef.update({
      'status': 'Acknowledged',
      'acknowledgedBy': userId,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Dismiss an alert with a required reason.
  Future<void> dismissAlert(
    String alertId,
    String userId,
    String reason,
  ) async {
    final alertRef = await _findAlertRef(alertId);
    if (alertRef == null) {
      throw Exception('Alert not found: $alertId');
    }

    await alertRef.update({
      'status': 'Dismissed',
      'acknowledgedBy': userId,
      'dismissalReason': reason,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resolve an alert.
  Future<void> resolveAlert(String alertId) async {
    final alertRef = await _findAlertRef(alertId);
    if (alertRef == null) {
      throw Exception('Alert not found: $alertId');
    }

    await alertRef.update({
      'status': 'Resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Find the Firestore reference for an alert by its ID.
  /// Alerts live under networkNodes/{nodeId}/alerts/{alertId} — we use a
  /// collection group query to locate the document.
  Future<DocumentReference?> _findAlertRef(String alertId) async {
    final snap = await _firestore
        .collectionGroup('alerts')
        .where(FieldPath.documentId, isEqualTo: alertId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.reference;
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