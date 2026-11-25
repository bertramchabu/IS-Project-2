import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/app_error_logger.dart';

/// An entry from the auditLogs collection (FR-SA-08, NFR-SE-05).
class AuditLogEntry {
  final String logId;
  final String userId;
  final String userName;
  final String action;
  final String details;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.logId,
    required this.userId,
    required this.userName,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AuditLogEntry(
      logId: doc.id,
      userId: d['userId'] as String? ?? 'unknown',
      userName: d['userName'] as String? ?? 'unknown',
      action: d['action'] as String? ?? '',
      details: d['details'] as String? ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, String> toCsvRow() => {
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'userName': userName,
        'action': action,
        'details': details,
      };
}

/// Known audit action identifiers.
class AuditActions {
  static const alertAcknowledged = 'ALERT_ACKNOWLEDGED';
  static const alertDismissed = 'ALERT_DISMISSED';
  static const alertResolved = 'ALERT_RESOLVED';
  static const alertsBulkAcknowledged = 'ALERTS_BULK_ACKNOWLEDGED';
  static const userCreated = 'USER_CREATED';
  static const userRoleChanged = 'USER_ROLE_CHANGED';
  static const userStatusChanged = 'USER_STATUS_CHANGED';
  static const nodeRegistered = 'NODE_REGISTERED';
  static const nodeStatusChanged = 'NODE_STATUS_CHANGED';
  static const thresholdUpdated = 'THRESHOLD_UPDATED';
  static const retrainRequested = 'MODEL_RETRAIN_REQUESTED';
}

class AuditRepository {
  final FirebaseFirestore _firestore;

  AuditRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _logs => _firestore.collection('auditLogs');

  /// Fire-and-forget audit write; monitoring flows must not fail because
  /// logging failed.
  Future<void> log({
    required String userId,
    required String userName,
    required String action,
    required String details,
  }) async {
    try {
      await _logs.add({
        'userId': userId,
        'userName': userName,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppErrorLogger.log('AuditRepository.write', e);
    }
  }

  /// Stream recent audit entries, optionally filtered to one user.
  /// The userId + timestamp composite index is declared in
  /// firestore.indexes.json.
  Stream<List<AuditLogEntry>> watchLogs({
    String? userId,
    String? action,
    int limit = 50,
  }) {
    Query query = _logs;
    if (userId != null && userId.isNotEmpty) {
      query = query.where('userId', isEqualTo: userId);
    }
    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map(AuditLogEntry.fromFirestore)
            .where((entry) => action == null || entry.action == action)
            .toList());
  }
}
