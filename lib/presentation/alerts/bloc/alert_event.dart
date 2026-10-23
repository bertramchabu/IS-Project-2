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

/// Acknowledge an alert.
class AlertAcknowledged extends AlertEvent {
  final String nodeId;
  final String alertId;
  final String userId;

  const AlertAcknowledged({
    required this.nodeId,
    required this.alertId,
    required this.userId,
  });

  @override
  List<Object?> get props => [nodeId, alertId, userId];
}

/// Dismiss an alert with a reason.
class AlertDismissed extends AlertEvent {
  final String nodeId;
  final String alertId;
  final String userId;
  final String reason;

  const AlertDismissed({
    required this.nodeId,
    required this.alertId,
    required this.userId,
    required this.reason,
  });

  @override
  List<Object?> get props => [nodeId, alertId, userId, reason];
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
