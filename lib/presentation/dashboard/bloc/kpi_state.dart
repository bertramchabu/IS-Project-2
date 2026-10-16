import 'package:equatable/equatable.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../../data/models/network_node_model.dart';

abstract class KpiState extends Equatable {
  const KpiState();

  @override
  List<Object?> get props => [];
}

class KpiInitial extends KpiState {
  const KpiInitial();
}

class KpiLoading extends KpiState {
  const KpiLoading();
}

class KpiLoaded extends KpiState {
  final List<NetworkNodeModel> nodes;
  final NetworkNodeModel? selectedNode;
  final List<KpiMetricModel> metrics;

  const KpiLoaded({
    required this.nodes,
    this.selectedNode,
    this.metrics = const [],
  });

  KpiLoaded copyWith({
    List<NetworkNodeModel>? nodes,
    NetworkNodeModel? selectedNode,
    List<KpiMetricModel>? metrics,
  }) {
    return KpiLoaded(
      nodes: nodes ?? this.nodes,
      selectedNode: selectedNode ?? this.selectedNode,
      metrics: metrics ?? this.metrics,
    );
  }

  /// Get the latest value for a specific metric type.
  double? latestValue(MetricType type) {
    final filtered =
        metrics.where((m) => m.metricType == type).toList();
    if (filtered.isEmpty) return null;
    return filtered.last.value;
  }

  /// Get time-series points for a specific metric type.
  List<KpiMetricModel> seriesFor(MetricType type) {
    return metrics.where((m) => m.metricType == type).toList();
  }

  @override
  List<Object?> get props => [nodes, selectedNode, metrics];
}

class KpiError extends KpiState {
  final String message;

  const KpiError(this.message);

  @override
  List<Object?> get props => [message];
}