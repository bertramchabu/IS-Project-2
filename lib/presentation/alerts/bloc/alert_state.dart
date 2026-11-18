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
  final AlertSeverity? severityFilter;
  final String? nodeFilter;
  final String query;

  const AlertLoaded({
    required this.alerts,
    this.statusFilter,
    this.severityFilter,
    this.nodeFilter,
    this.query = '',
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

  /// Distinct node ids present in the stream, for the node filter dropdown.
  List<String> get nodeOptions {
    final names = <String>{};
    for (final alert in alerts) {
      names.add(alert.nodeName ?? alert.nodeId);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  /// Counts per status for the filter chips.
  Map<AlertStatus, int> get statusCounts {
    final counts = <AlertStatus, int>{};
    for (final status in AlertStatus.values) {
      counts[status] = alerts.where((a) => a.status == status).length;
    }
    return counts;
  }

  /// Alerts narrowed by every active filter (FR-NA-06).
  List<AlertModel> get filteredAlerts {
    Iterable<AlertModel> result = alerts;
    if (statusFilter != null) {
      result = result.where((a) => a.status == statusFilter);
    }
    if (severityFilter != null) {
      result = result.where((a) => a.severity == severityFilter);
    }
    if (nodeFilter != null && nodeFilter!.isNotEmpty) {
      result = result.where((a) =>
          a.nodeId == nodeFilter || (a.nodeName ?? '') == nodeFilter);
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((a) =>
          a.title.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          (a.nodeName ?? a.nodeId).toLowerCase().contains(q));
    }
    return result.toList();
  }

  AlertLoaded copyWith({
    List<AlertModel>? alerts,
    AlertStatus? statusFilter,
    bool clearStatusFilter = false,
    AlertSeverity? severityFilter,
    bool clearSeverityFilter = false,
    String? nodeFilter,
    bool clearNodeFilter = false,
    String? query,
  }) {
    return AlertLoaded(
      alerts: alerts ?? this.alerts,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      severityFilter:
          clearSeverityFilter ? null : (severityFilter ?? this.severityFilter),
      nodeFilter: clearNodeFilter ? null : (nodeFilter ?? this.nodeFilter),
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props =>
      [alerts, statusFilter, severityFilter, nodeFilter, query];
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
    required super.alerts,
    required this.message,
    super.statusFilter,
    super.severityFilter,
    super.nodeFilter,
    super.query,
  });

  @override
  List<Object?> get props =>
      [alerts, message, statusFilter, severityFilter, nodeFilter, query];
}
