import 'package:equatable/equatable.dart';
import '../../../data/models/alert_model.dart';

abstract class AlertState extends Equatable {
  const AlertState();

  @override
  List<Object?> get props => [];
}

class AlertInitial extends AlertState {
  const AlertInitial();
}

class AlertLoading extends AlertState {
  const AlertLoading();
}

class AlertLoaded extends AlertState {
  final List<AlertModel> alerts;
  final AlertStatus? statusFilter;

  const AlertLoaded({
    required this.alerts,
    this.statusFilter,
  });

  /// Active alerts only.
  List<AlertModel> get activeAlerts =>
      alerts.where((a) => a.isActive).toList();

  /// Critical alerts only.
  List<AlertModel> get criticalAlerts =>
      alerts.where((a) => a.isCritical && a.isActive).toList();

  /// Count of active alerts.
  int get activeCount => activeAlerts.length;

  /// Count of active critical alerts.
  int get criticalCount => criticalAlerts.length;

  /// Alerts filtered by current status filter (if set).
  List<AlertModel> get filteredAlerts {
    if (statusFilter == null) return alerts;
    return alerts.where((a) => a.status == statusFilter).toList();
  }

  AlertLoaded copyWith({
    List<AlertModel>? alerts,
    AlertStatus? statusFilter,
    bool clearFilter = false,
  }) {
    return AlertLoaded(
      alerts: alerts ?? this.alerts,
      statusFilter: clearFilter ? null : (statusFilter ?? this.statusFilter),
    );
  }

  @override
  List<Object?> get props => [alerts, statusFilter];
}

class AlertError extends AlertState {
  final String message;

  const AlertError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Emitted transiently after an action succeeds (UI shows a SnackBar).
class AlertActionSuccess extends AlertLoaded {
  final String message;

  const AlertActionSuccess({
    required List<AlertModel> alerts,
    required this.message,
    super.statusFilter,
  }) : super(alerts: alerts);

  @override
  List<Object?> get props => [alerts, message, statusFilter];
}