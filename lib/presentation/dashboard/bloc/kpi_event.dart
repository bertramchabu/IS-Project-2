import 'package:equatable/equatable.dart';
import '../../../data/models/kpi_metric_model.dart';

abstract class KpiEvent extends Equatable {
  const KpiEvent();

  @override
  List<Object?> get props => [];
}

/// Load all nodes and subscribe to the first one.
class DashboardStarted extends KpiEvent {
  const DashboardStarted();
}

/// User selected a node in the sidebar.
class NodeSelected extends KpiEvent {
  final String nodeId;

  const NodeSelected(this.nodeId);

  @override
  List<Object?> get props => [nodeId];
}

/// Internal event for when a KPI stream emits new data.
class KpiMetricsUpdated extends KpiEvent {
  final List<KpiMetricModel> metrics;

  const KpiMetricsUpdated(this.metrics);

  @override
  List<Object?> get props => [metrics];
}

/// Internal event for when the node list updates.
class NodesUpdated extends KpiEvent {
  final List nodes;

  const NodesUpdated(this.nodes);

  @override
  List<Object?> get props => [nodes];
}
class KpiStreamError extends KpiEvent {
  final String message;

  const KpiStreamError(this.message);

  @override
  List<Object?> get props => [message];
}