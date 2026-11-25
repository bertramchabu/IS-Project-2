import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_error_logger.dart';
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
  bool _simulationMode = false;

  KpiBloc({
    required NodeRepository nodeRepo,
    required KpiRepository kpiRepo,
  })  : _nodeRepo = nodeRepo,
        _kpiRepo = kpiRepo,
        super(const KpiInitial()) {
    on<DashboardStarted>(_onStarted);
    on<NodeSelected>(_onNodeSelected);
    on<KpiMetricsUpdated>(_onMetricsUpdated);
    on<KpiSimulationModeChanged>(_onSimulationModeChanged);
    on<KpiSimulationMetricsUpdated>(_onSimulationMetricsUpdated);
    on<NodesUpdated>(_onNodesUpdated);
    on<KpiStreamError>(_onStreamError);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    AppErrorLogger.log('KpiBloc.unhandled', error);
    super.onError(error, stackTrace);
  }

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<KpiState> emit,
  ) async {
    emit(const KpiLoading());

    await _nodesSub?.cancel();
    _nodesSub = _nodeRepo.watchAllNodes().listen(
      (nodes) => add(NodesUpdated(nodes)),
      onError: (Object error) {
        AppErrorLogger.log('KpiBloc.nodesStream', error);
        add(KpiStreamError(error.toString()));
      },
    );
  }

  Future<void> _onNodesUpdated(
    NodesUpdated event,
    Emitter<KpiState> emit,
  ) async {
    final nodes = event.nodes;

    if (nodes.isEmpty) {
      return emit(KpiLoaded(nodes: nodes));
    }

    // First load: auto-select the first node
    final current = state;
    if (current is! KpiLoaded || current.selectedNode == null) {
      // Defer selection so we don't emit twice in the same handler
      add(NodeSelected(nodes.first.nodeId));
      return emit(KpiLoaded(
        nodes: nodes,
        selectedNode: nodes.first,
      ));
    }

    emit(current.copyWith(nodes: nodes));
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
    _subscribeToMetrics(event.nodeId);
  }

  void _subscribeToMetrics(String nodeId) {
    _metricsSub = _kpiRepo.watchLatestPerType(nodeId).listen(
      (metrics) => add(KpiMetricsUpdated(metrics)),
      onError: (Object error) {
        AppErrorLogger.log('KpiBloc.metricsStream', error);
        add(KpiStreamError(error.toString()));
      },
    );
  }

  Future<void> _onMetricsUpdated(
    KpiMetricsUpdated event,
    Emitter<KpiState> emit,
  ) async {
    if (_simulationMode) return;
    final current = state;
    if (current is KpiLoaded) {
      emit(current.copyWith(metrics: event.metrics));
    }
  }

  Future<void> _onSimulationModeChanged(
    KpiSimulationModeChanged event,
    Emitter<KpiState> emit,
  ) async {
    _simulationMode = event.isEnabled;
    final current = state;
    if (current is! KpiLoaded) return;

    emit(current.copyWith(metrics: const []));
    if (!event.isEnabled && current.selectedNode != null) {
      await _metricsSub?.cancel();
      _subscribeToMetrics(current.selectedNode!.nodeId);
    }
  }

  Future<void> _onSimulationMetricsUpdated(
    KpiSimulationMetricsUpdated event,
    Emitter<KpiState> emit,
  ) async {
    final current = state;
    if (!_simulationMode ||
        current is! KpiLoaded ||
        current.selectedNode?.nodeId != event.nodeId) {
      return;
    }

    final metrics = [...current.metrics, ...event.metrics];
    emit(current.copyWith(
      metrics: metrics.length > 750
          ? metrics.sublist(metrics.length - 750)
          : metrics,
    ));
  }

  Future<void> _onStreamError(
    KpiStreamError event,
    Emitter<KpiState> emit,
  ) async {
    AppErrorLogger.log('KpiBloc.streamMessage', event.message);
    emit(KpiError(event.message));
  }

  @override
  Future<void> close() {
    _nodesSub?.cancel();
    _metricsSub?.cancel();
    return super.close();
  }
}
