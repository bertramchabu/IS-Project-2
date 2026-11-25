import 'package:cloud_firestore/cloud_firestore.dart';

/// Severity level of an alert (matches Firestore severityLevels collection).
enum AlertSeverity { low, medium, high, critical }

extension AlertSeverityId on AlertSeverity {
  String get severityId => switch (this) {
        AlertSeverity.low => 'low',
        AlertSeverity.medium => 'medium',
        AlertSeverity.high => 'high',
        AlertSeverity.critical => 'critical',
      };
}

/// Lifecycle state of an alert.
enum AlertStatus { active, acknowledged, dismissed, resolved }

class AlertModel {
  final String alertId;
  final String nodeId;
  final String? predictionId;
  final AlertSeverity severity;
  final AlertStatus status;
  final String title;
  final String description;
  final String? acknowledgedBy;
  final String? dismissalReason;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  /// Populated from a join with networkNodes — not stored on the alert doc itself.
  final String? nodeName;

  const AlertModel({
    required this.alertId,
    required this.nodeId,
    this.predictionId,
    required this.severity,
    required this.status,
    required this.title,
    required this.description,
    this.acknowledgedBy,
    this.dismissalReason,
    required this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.nodeName,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc,
      {String? nodeName}) {
    final d = doc.data() as Map<String, dynamic>;
    return AlertModel(
      alertId: doc.id,
      nodeId: d['nodeId'] as String? ?? '',
      predictionId: d['predictionId'] as String?,
      severity: _parseSeverity(d['severityId'] as String?),
      status: _parseStatus(d['status'] as String?),
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      acknowledgedBy: d['acknowledgedBy'] as String?,
      dismissalReason: d['dismissalReason'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acknowledgedAt: (d['acknowledgedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      nodeName: nodeName,
    );
  }

  static AlertSeverity _parseSeverity(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'low':
        return AlertSeverity.low;
      case 'medium':
        return AlertSeverity.medium;
      case 'high':
        return AlertSeverity.high;
      case 'critical':
        return AlertSeverity.critical;
      default:
        return AlertSeverity.low;
    }
  }

  static AlertStatus _parseStatus(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'active':
        return AlertStatus.active;
      case 'acknowledged':
        return AlertStatus.acknowledged;
      case 'dismissed':
        return AlertStatus.dismissed;
      case 'resolved':
        return AlertStatus.resolved;
      default:
        return AlertStatus.active;
    }
  }

  /// Firestore severity id (used when writing back).
  String get severityId {
    switch (severity) {
      case AlertSeverity.low:
        return 'low';
      case AlertSeverity.medium:
        return 'medium';
      case AlertSeverity.high:
        return 'high';
      case AlertSeverity.critical:
        return 'critical';
    }
  }

  /// Firestore status id (used when writing back).
  String get statusId {
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

  String get severityLabel {
    switch (severity) {
      case AlertSeverity.low:
        return 'LOW';
      case AlertSeverity.medium:
        return 'MEDIUM';
      case AlertSeverity.high:
        return 'HIGH';
      case AlertSeverity.critical:
        return 'CRITICAL';
    }
  }

  String get statusLabel {
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

  bool get isActive => status == AlertStatus.active;
  bool get isCritical => severity == AlertSeverity.critical;
  bool get isHighOrAbove =>
      severity == AlertSeverity.high || severity == AlertSeverity.critical;

  AlertModel copyWith({
    AlertStatus? status,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    String? dismissalReason,
    DateTime? resolvedAt,
    String? nodeName,
  }) {
    return AlertModel(
      alertId: alertId,
      nodeId: nodeId,
      predictionId: predictionId,
      severity: severity,
      status: status ?? this.status,
      title: title,
      description: description,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      dismissalReason: dismissalReason ?? this.dismissalReason,
      createdAt: createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      nodeName: nodeName ?? this.nodeName,
    );
  }
}