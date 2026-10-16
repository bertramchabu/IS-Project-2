import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../../data/models/network_node_model.dart';
import '../../../data/repositories/kpi_repository.dart';
import '../../../data/repositories/node_repository.dart';
import 'kpi_event.dart';
import 'kpi_state.dart';

class KpiBloc extends Bloc<KpiEvent, KpiState> {
  final NodeRepository _nodeRepo;
  final KpiRepository _kpiRepo;

  StreamSubscription? _nodesSub;
  StreamSubscription? _metricsSub;

  KpiBloc({
    required NodeRepository nodeRepo,
    required KpiRepository kpiRepo,
  })  : _nodeRepo = nodeRepo,
        _kpiRepo = kpiRepo,
        super(const KpiInitial()) {
    on<DashboardStarted>(_onStarted);
    on<NodeSelected>(_onNodeSelected);
    on<KpiMetricsUpdated>(_onMetricsUpdated);
    on<NodesUpdated>(_onNodesUpdated);
  }

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<KpiState> emit,
  ) async {
    emit(const KpiLoading());

    _nodesSub = _nodeRepo.watchAllNodes().listen(
      (nodes) {
        add(NodesUpdated(nodes));
        if (state is KpiInitial || (state is KpiLoading)) {
          if (nodes.isNotEmpty) {
            add(NodeSelected(nodes.first.nodeId));
          }
        }
      },
      onError: (e) => emit(KpiError(e.toString())),
    );
  }

  Future<void> _onNodesUpdated(
    NodesUpdated event,
    Emitter<KpiState> emit,
  ) async {
    final nodes = event.nodes as List<NetworkNodeModel>;
    final current = state;

    if (current is KpiLoaded) {
      emit(current.copyWith(nodes: nodes));
    } else {
      emit(KpiLoaded(
        nodes: nodes,
        selectedNode: nodes.isNotEmpty ? nodes.first : null,
      ));
    }
  }

  Future<void> _onNodeSelected(
    NodeSelected event,
    Emitter<KpiState> emit,
  ) async {
    final current = state;
    final nodes = current is KpiLoaded ? current.nodes : <NetworkNodeModel>[];
    final selected = nodes.firstWhere(
      (n) => n.nodeId == event.nodeId,
      orElse: () => nodes.first,
    );

    emit(KpiLoaded(
      nodes: nodes,
      selectedNode: selected,
      metrics: const [],
    ));

    // Cancel previous metric subscription
    await _metricsSub?.cancel();

    // Subscribe to all recent metrics for this node
    _metricsSub = _kpiRepo
        .watchLatestPerType(event.nodeId)
        .listen(
          (metrics) => add(KpiMetricsUpdated(metrics)),
          onError: (e) => emit(KpiError(e.toString())),
        );
  }

  Future<void> _onMetricsUpdated(
    KpiMetricsUpdated event,
    Emitter<KpiState> emit,
  ) async {
    final current = state;
    if (current is KpiLoaded) {
      emit(current.copyWith(metrics: event.metrics));
    }
  }

  @override
  Future<void> close() {
    _nodesSub?.cancel();
    _metricsSub?.cancel();
    return super.close();
  }
}