import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    on<KpiStreamError>(_onStreamError);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('[KpiBloc] Unhandled error: $error');
    super.onError(error, stackTrace);
  }

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<KpiState> emit,
  ) async {
    emit(const KpiLoading());

    await _nodesSub?.cancel();
    _nodesSub = _nodeRepo.watchAllNodes().listen(
      (nodes) => add(NodesUpdated(nodes)),                  // ✅ event, not emit
      onError: (e) => add(KpiStreamError(e.toString())),    // ✅ event, not emit
    );
  }
  Future<void> _onNodesUpdated(
    NodesUpdated event,
    Emitter<KpiState> emit,
  ) async {
    final nodes = event.nodes;

    if (nodes.isEmpty) {
      return emit(KpiLoaded(nodes: nodes as List<NetworkNodeModel>));
    }

    // First load: auto-select the first node
    final current = state;
    if (current is! KpiLoaded || current.selectedNode == null) {
      // Defer selection so we don't emit twice in the same handler
      add(NodeSelected(nodes.first.nodeId));
      return emit(KpiLoaded(
        nodes: nodes as List<NetworkNodeModel>,
        selectedNode: nodes.first,
      ));
    }

    emit(current.copyWith(nodes: nodes as List<NetworkNodeModel>));
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
          onError: (e) => add(KpiStreamError(e.toString())),
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
Future<void> _onStreamError(
    KpiStreamError event,
    Emitter<KpiState> emit,
  ) async {
    print('[KpiBloc] Stream error: ${event.message}');
    emit(KpiError(event.message));
  }
