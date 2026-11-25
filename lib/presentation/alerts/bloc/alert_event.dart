import 'package:equatable/equatable.dart';
import '../../../data/models/alert_model.dart';

abstract class AlertEvent extends Equatable {
  const AlertEvent();

  @override
  List<Object?> get props => [];
}

/// Start streaming alerts (invoked once on dashboard load).
class AlertsStarted extends AlertEvent {
  const AlertsStarted();
}

/// Filter by status (null = all).
class AlertStatusFilterChanged extends AlertEvent {
  final AlertStatus? filter;

  const AlertStatusFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Filter by severity (null = all).
class AlertSeverityFilterChanged extends AlertEvent {
  final AlertSeverity? filter;

  const AlertSeverityFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Filter by node id (null = all).
class AlertNodeFilterChanged extends AlertEvent {
  final String? nodeId;

  const AlertNodeFilterChanged(this.nodeId);

  @override
  List<Object?> get props => [nodeId];
}

/// Free-text search over title, description and node name.
class AlertQueryChanged extends AlertEvent {
  final String query;

  const AlertQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Acknowledge an alert.
class AlertAcknowledged extends AlertEvent {
  final String nodeId;
  final String alertId;
  final String userId;
  final String userName;

  const AlertAcknowledged({
    required this.nodeId,
    required this.alertId,
    required this.userId,
    this.userName = '',
  });

  @override
  List<Object?> get props => [nodeId, alertId, userId, userName];
}

/// Acknowledge many alerts in one action (FR-NA-06 bulk handling).
class AlertsBulkAcknowledged extends AlertEvent {
  final List<AlertModel> alerts;
  final String userId;
  final String userName;

  const AlertsBulkAcknowledged({
    required this.alerts,
    required this.userId,
    this.userName = '',
  });

  @override
  List<Object?> get props => [alerts, userId, userName];
}

/// Resolve an acknowledged alert once the underlying issue is cleared.
class AlertResolved extends AlertEvent {
  final String nodeId;
  final String alertId;
  final String userId;
  final String userName;

  const AlertResolved({
    required this.nodeId,
    required this.alertId,
    required this.userId,
    this.userName = '',
  });

  @override
  List<Object?> get props => [nodeId, alertId, userId, userName];
}

/// Dismiss an alert with a reason.
class AlertDismissed extends AlertEvent {
  final String nodeId;
  final String alertId;
  final String userId;
  final String userName;
  final String reason;

  const AlertDismissed({
    required this.nodeId,
    required this.alertId,
    required this.userId,
    this.userName = '',
    required this.reason,
  });

  @override
  List<Object?> get props => [nodeId, alertId, userId, userName, reason];
}

/// Internal event fired when the Firestore stream emits.
class AlertsReceived extends AlertEvent {
  final List<AlertModel> alerts;

  const AlertsReceived(this.alerts);

  @override
  List<Object?> get props => [alerts];
}

class AlertStreamError extends AlertEvent {
  final String message;
  const AlertStreamError(this.message);

  @override
  List<Object?> get props => [message];
}
