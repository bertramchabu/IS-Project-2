// network_admin_home.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../../data/models/network_node_model.dart';
import '../../../data/models/user_models.dart';
import '../../../di/service_locator.dart' as di;
import '../../../services/csv_telemetry_replay.dart';
import '../../alerts/bloc/alert_bloc.dart';
import '../../alerts/bloc/alert_event.dart';
import '../../alerts/bloc/alert_state.dart';
import '../../alerts/widgets/alert_panel.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/widgets/user_profile_dialog.dart';
import '../../widgets/glass_ui.dart';
import '../../widgets/web_safe_backdrop_blur.dart';
import '../bloc/kpi_bloc.dart';
import '../bloc/kpi_event.dart';
import '../bloc/kpi_state.dart';
import '../bloc/prediction_bloc.dart';
import '../bloc/prediction_event.dart';
import '../bloc/prediction_state.dart';
import '../widgets/fault_gauge.dart';
import '../widgets/kpi_line_chart.dart';
import '../widgets/node_map.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _AppColors {
  static const bg = Color(0xFF070B14);
  static const accent = Color(0xFF00E5FF);
  static const healthy = Color(0xFF00FF9D);
  static const warning = Color(0xFFFFB300);
  static const critical = Color(0xFFFF0055);
  static const unknown = Color(0xFF64748B);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

class NetworkAdminHome extends StatelessWidget {
  const NetworkAdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => di.sl<KpiBloc>()..add(const DashboardStarted())),
        BlocProvider(
            create: (_) => di.sl<AlertBloc>()..add(const AlertsStarted())),
        BlocProvider(create: (_) => di.sl<PredictionBloc>()),
      ],
      child: const _DashboardShell(),
    );
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell();

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell> {
  CsvTelemetryReplay? _telemetryReplay;
  Timer? _simulationTimer;
  bool _replayLoading = false;
  bool _autoReplayAttempted = false;
  String? _predictionNodeId;

  bool get _isSimulationActive => _simulationTimer != null;

  Future<void> _toggleSimulation() async {
    if (_isSimulationActive) {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      final kpiBloc = context.read<KpiBloc>();
      kpiBloc.add(const KpiSimulationModeChanged(false));
      final current = kpiBloc.state;
      if (current is KpiLoaded && current.selectedNode != null) {
        context
            .read<PredictionBloc>()
            .add(PredictionStarted(current.selectedNode!.nodeId));
      }
      setState(() {});
      return;
    }
    await _startCsvReplay();
  }

  Future<void> _startCsvReplay() async {
    final kpiBloc = context.read<KpiBloc>();
    final current = kpiBloc.state;
    if (current is! KpiLoaded || current.selectedNode == null) return;

    if (_replayLoading) return;
    setState(() => _replayLoading = true);
    try {
      _telemetryReplay ??= await CsvTelemetryReplay.load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load CSV telemetry: $error')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _replayLoading = false);
    }
    if (!mounted) return;

    final replayState = kpiBloc.state;
    if (replayState is! KpiLoaded || replayState.selectedNode == null) return;
    final locationIndex =
        _locationIndexFor(replayState.nodes, replayState.selectedNode!.nodeId);

    if (locationIndex < 0 ||
        locationIndex >= _telemetryReplay!.sourceIds.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'CSV replay cannot map this location\'s alphabetical position.')),
      );
      return;
    }

    kpiBloc.add(const KpiSimulationModeChanged(true));
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = kpiBloc.state;
      final selectedNode = state is KpiLoaded ? state.selectedNode : null;
      if (state is! KpiLoaded || selectedNode == null) return;

      final timestamp = DateTime.now();
      final locIndex = _locationIndexFor(state.nodes, selectedNode.nodeId);
      if (locIndex < 0 || locIndex >= _telemetryReplay!.sourceIds.length) {
        _simulationTimer?.cancel();
        _simulationTimer = null;
        kpiBloc.add(const KpiSimulationModeChanged(false));
        if (mounted) setState(() {});
        return;
      }
      kpiBloc.add(KpiSimulationMetricsUpdated(
        nodeId: selectedNode.nodeId,
        metrics: _telemetryReplay!.sample(
          locationIndex: locIndex,
          nodeId: selectedNode.nodeId,
          timestamp: timestamp,
        ),
      ));
    });
    setState(() {});
  }

  int _locationIndexFor(List<NetworkNodeModel> nodes, String nodeId) {
    final orderedNodes = [...nodes]..sort((a, b) {
        final byName = a.nodeName.compareTo(b.nodeName);
        return byName != 0 ? byName : a.nodeId.compareTo(b.nodeId);
      });
    return orderedNodes.indexWhere((node) => node.nodeId == nodeId);
  }

  void _startPredictionForNode(String nodeId) {
    if (_predictionNodeId == nodeId) return;
    _predictionNodeId = nodeId;
    context.read<PredictionBloc>().add(PredictionStarted(nodeId));
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authenticatedUserFrom(authState);
    final username = user?.username ?? 'User';
    final initials = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final kpiState = context.watch<KpiBloc>().state;
    final predictionState = context.watch<PredictionBloc>().state;

    if (!_autoReplayAttempted &&
        kpiState is KpiLoaded &&
        kpiState.selectedNode != null) {
      _autoReplayAttempted = true;
      final nodeId = kpiState.selectedNode!.nodeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startPredictionForNode(nodeId);
          unawaited(_startCsvReplay());
        }
      });
    }
    final lastMetricUpdate =
        kpiState is KpiLoaded && kpiState.metrics.isNotEmpty
            ? kpiState.metrics
                .map((metric) => metric.timestamp)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : null;
    final modelReady = predictionState is PredictionLoaded &&
        predictionState.modelApiOnline &&
        predictionState.modelLoaded;

    return Scaffold(
      backgroundColor: _AppColors.bg,
      // Futuristic background gradient to support glassmorphism
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: [Color(0xFF0F1A30), _AppColors.bg],
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(
              context,
              user,
              username,
              initials,
              lastMetricUpdate,
              modelReady,
              _isSimulationActive,
              _replayLoading,
              _toggleSimulation,
            ),
            Expanded(
              child: MultiBlocListener(
                listeners: [
                  BlocListener<KpiBloc, KpiState>(
                    listenWhen: (previous, current) {
                      if (current is! KpiLoaded) return false;
                      if (previous is! KpiLoaded) return true;
                      return current.selectedNode?.nodeId !=
                          previous.selectedNode?.nodeId;
                    },
                    listener: (context, state) {
                      if (state is KpiLoaded && state.selectedNode != null) {
                        _startPredictionForNode(state.selectedNode!.nodeId);
                      }
                    },
                  ),
                  BlocListener<KpiBloc, KpiState>(
                    listenWhen: (previous, current) {
                      if (current is! KpiLoaded || current.metrics.isEmpty)
                        return false;
                      if (previous is! KpiLoaded) return true;
                      return previous.selectedNode?.nodeId ==
                              current.selectedNode?.nodeId &&
                          previous.metrics != current.metrics;
                    },
                    listener: (context, state) {
                      if (state is KpiLoaded && state.selectedNode != null) {
                        context
                            .read<PredictionBloc>()
                            .add(PredictionMetricsReceived(
                              nodeId: state.selectedNode!.nodeId,
                              metrics: state.metrics,
                            ));
                      }
                    },
                  ),
                ],
                child: BlocBuilder<KpiBloc, KpiState>(
                  builder: (context, state) {
                    if (state is KpiLoading) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: _AppColors.accent));
                    }
                    if (state is KpiError) {
                      return _ErrorView(message: state.message);
                    }
                    if (state is KpiLoaded) {
                      return _DashboardBody(state: state);
                    }
                    return const Center(
                        child: Text('Initialising...',
                            style: TextStyle(color: _AppColors.textSecondary)));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    UserModel? user,
    String username,
    String initials,
    DateTime? lastMetricUpdate,
    bool modelReady,
    bool simulationActive,
    bool replayLoading,
    VoidCallback onSimulationToggle,
  ) {
    final compactActions = MediaQuery.sizeOf(context).width < 900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_AppColors.accent, Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: _AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 12)
              ],
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NetVision AI',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: _AppColors.textPrimary)),
              Text('Network Operations Center',
                  style: TextStyle(
                      fontSize: 10,
                      color: _AppColors.textMuted,
                      letterSpacing: 0.4)),
            ],
          ),
          const Spacer(),
          if (compactActions)
            IconButton(
              onPressed: replayLoading ? null : onSimulationToggle,
              icon: replayLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      simulationActive
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline_rounded,
                      color: simulationActive
                          ? _AppColors.warning
                          : _AppColors.accent),
            )
          else
            TextButton.icon(
              onPressed: replayLoading ? null : onSimulationToggle,
              icon: replayLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      simulationActive
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline_rounded,
                      size: 18),
              label: Text(replayLoading
                  ? 'LOADING DATA'
                  : simulationActive
                      ? 'STOP REPLAY'
                      : 'LIVE REPLAY'),
              style: TextButton.styleFrom(
                foregroundColor:
                    simulationActive ? _AppColors.warning : _AppColors.accent,
              ),
            ),
          const SizedBox(width: 12),
          _LiveIndicator(
              lastMetricUpdate: lastMetricUpdate,
              modelReady: modelReady,
              simulationActive: simulationActive),
          const SizedBox(width: 12),
          _UserChip(user: user, username: username, initials: initials),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: _AppColors.textSecondary, size: 20),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  final DateTime? lastMetricUpdate;
  final bool modelReady;
  final bool simulationActive;

  const _LiveIndicator(
      {required this.lastMetricUpdate,
      required this.modelReady,
      required this.simulationActive});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (tick) => tick),
      initialData: 0,
      builder: (context, _) {
        final age = lastMetricUpdate == null
            ? null
            : DateTime.now().difference(lastMetricUpdate!);
        final isFresh = age != null &&
            age >= Duration.zero &&
            age <= const Duration(seconds: 5);
        final dataColor = simulationActive
            ? _AppColors.accent
            : isFresh
                ? _AppColors.healthy
                : lastMetricUpdate == null
                    ? _AppColors.unknown
                    : _AppColors.warning;
        final dataLabel = simulationActive
            ? 'DEMO LIVE'
            : isFresh
                ? 'DATA LIVE'
                : lastMetricUpdate == null
                    ? 'WAITING'
                    : 'STALE DATA';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusBadge(label: dataLabel, color: dataColor),
            const SizedBox(width: 8),
            _StatusBadge(
                label: modelReady ? 'MODEL READY' : 'MODEL OFFLINE',
                color: modelReady ? _AppColors.accent : _AppColors.unknown),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  final UserModel? user;
  final String username;
  final String initials;
  const _UserChip({this.user, required this.username, required this.initials});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: user == null ? null : () => UserProfileDialog.show(context, user!),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: _AppColors.accent.withValues(alpha: 0.2),
              child: Text(initials,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.accent)),
            ),
            const SizedBox(width: 8),
            Text(username,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.textPrimary)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: _AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassCard(
        padding: const EdgeInsets.all(24),
        borderColor: _AppColors.critical.withValues(alpha: 0.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: _AppColors.critical, size: 32),
            const SizedBox(height: 12),
            Text('Error: $message',
                style: const TextStyle(color: _AppColors.critical)),
          ],
        ),
      ),
    );
  }
}

// --- SHARED GLASS CARD COMPONENT ---
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: padding,
      radius: 16,
      tint: const Color(0xFF111827),
      borderColor: borderColor,
      blurSigma: 12,
      child: child,
    );
  }
}

class _DashboardBody extends StatefulWidget {
  final KpiLoaded state;
  const _DashboardBody({required this.state});

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  bool _alertsOpen = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth =
            math.min(400.0, math.max(0.0, constraints.maxWidth - 24));
        return Stack(
          children: [
            Positioned.fill(child: _DashboardContent(state: widget.state)),
            if (_alertsOpen)
              Positioned(
                top: 12,
                right: 12,
                bottom: 12,
                width: panelWidth,
                child: AlertPanel(
                    width: null,
                    onClose: () => setState(() => _alertsOpen = false)),
              )
            else
              Positioned(
                right: 16,
                bottom: constraints.maxWidth < 720 ? 16 : null,
                top: constraints.maxWidth < 720 ? null : 16,
                child: _AlertOverlayButton(
                    onPressed: () => setState(() => _alertsOpen = true)),
              ),
          ],
        );
      },
    );
  }
}

class _AlertOverlayButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AlertOverlayButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertBloc, AlertState>(
      builder: (context, state) {
        final activeCount = state is AlertLoaded ? state.activeCount : 0;
        final hasCritical = state is AlertLoaded && state.criticalCount > 0;
        final indicator = hasCritical
            ? _AppColors.critical
            : activeCount > 0
                ? _AppColors.warning
                : _AppColors.accent;

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: WebSafeBackdropBlur(
            sigma: 16,
            child: Material(
              color: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: indicator.withValues(alpha: 0.4)),
              ),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active_rounded,
                          color: indicator, size: 18),
                      const SizedBox(width: 8),
                      const Text('Alerts',
                          style: TextStyle(
                              color: _AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: indicator,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('$activeCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final KpiLoaded state;
  const _DashboardContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) return _buildNarrowDashboard(context);

        final showSidebars = constraints.maxWidth >= 1300;
        return Row(
          children: [
            if (showSidebars) _Sidebar(state: state),
            Expanded(
                child: _buildWideDashboard(context,
                    showNodeSelector: !showSidebars)),
          ],
        );
      },
    );
  }

  Widget _buildWideDashboard(BuildContext context,
      {required bool showNodeSelector}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const _SectionHeader(
            title: 'Performance & Prediction Telemetry',
            subtitle: 'Real-time KPI monitoring & BiLSTM fault anticipation',
          ),
          if (showNodeSelector) ...[
            const SizedBox(height: 12),
            _buildNodeSelector(context),
          ],
          const SizedBox(height: 14),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: KpiLineChart(
                              title: 'Latency',
                              unit: 'ms',
                              color: _AppColors.accent,
                              metrics: state.seriesFor(MetricType.latency),
                              warningThreshold: 80,
                              criticalThreshold: 120)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: KpiLineChart(
                              title: 'Jitter',
                              unit: 'ms',
                              color: const Color(0xFFA78BFA),
                              metrics: state.seriesFor(MetricType.jitter),
                              warningThreshold: 30,
                              criticalThreshold: 50)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: KpiLineChart(
                              title: 'Packet Loss',
                              unit: '%',
                              color: const Color(0xFFFB923C),
                              metrics: state.seriesFor(MetricType.packetLoss),
                              warningThreshold: 1.5,
                              criticalThreshold: 3.0)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: KpiLineChart(
                              title: 'Retransmission',
                              unit: '%',
                              color: const Color(0xFF38BDF8),
                              metrics: state
                                  .seriesFor(MetricType.retransmissionRate))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: KpiLineChart(
                              title: 'Signal Strength',
                              unit: 'dBm',
                              color: const Color(0xFF4ADE80),
                              metrics:
                                  state.seriesFor(MetricType.signalStrength))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeader(
              title: 'Network Topology & Predictive Gauge',
              subtitle:
                  '${state.nodes.length} nodes • tap node to inspect live prediction'),
          const SizedBox(height: 14),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildNodeMap(context)),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: _buildPredictionGauge()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
              title: 'Network Monitoring',
              subtitle: 'Live KPI telemetry and BiLSTM fault anticipation'),
          const SizedBox(height: 12),
          _buildNodeSelector(context),
          const SizedBox(height: 16),
          SizedBox(
              height: 220,
              child: KpiLineChart(
                  title: 'Latency',
                  unit: 'ms',
                  color: _AppColors.accent,
                  metrics: state.seriesFor(MetricType.latency),
                  warningThreshold: 80,
                  criticalThreshold: 120)),
          const SizedBox(height: 12),
          SizedBox(
              height: 220,
              child: KpiLineChart(
                  title: 'Jitter',
                  unit: 'ms',
                  color: const Color(0xFFA78BFA),
                  metrics: state.seriesFor(MetricType.jitter),
                  warningThreshold: 30,
                  criticalThreshold: 50)),
          const SizedBox(height: 12),
          SizedBox(
              height: 220,
              child: KpiLineChart(
                  title: 'Packet Loss',
                  unit: '%',
                  color: const Color(0xFFFB923C),
                  metrics: state.seriesFor(MetricType.packetLoss),
                  warningThreshold: 1.5,
                  criticalThreshold: 3.0)),
          const SizedBox(height: 12),
          SizedBox(
              height: 220,
              child: KpiLineChart(
                  title: 'Retransmission',
                  unit: '%',
                  color: const Color(0xFF38BDF8),
                  metrics: state.seriesFor(MetricType.retransmissionRate))),
          const SizedBox(height: 12),
          SizedBox(
              height: 220,
              child: KpiLineChart(
                  title: 'Signal Strength',
                  unit: 'dBm',
                  color: const Color(0xFF4ADE80),
                  metrics: state.seriesFor(MetricType.signalStrength))),
          const SizedBox(height: 20),
          _SectionHeader(
              title: 'Network Topology',
              subtitle: '${state.nodes.length} nodes'),
          const SizedBox(height: 12),
          SizedBox(height: 320, child: _buildNodeMap(context)),
          const SizedBox(height: 12),
          SizedBox(height: 460, child: _buildPredictionGauge()),
        ],
      ),
    );
  }

  Widget _buildNodeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.selectedNode?.nodeId,
          isExpanded: true,
          dropdownColor: const Color(0xFF111827),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _AppColors.accent),
          hint: const Text('Select network node',
              style: TextStyle(color: _AppColors.textMuted)),
          items: state.nodes
              .map((node) => DropdownMenuItem(
                    value: node.nodeId,
                    child: Text(node.nodeName,
                        style: const TextStyle(color: _AppColors.textPrimary)),
                  ))
              .toList(),
          onChanged: (nodeId) {
            if (nodeId != null)
              context.read<KpiBloc>().add(NodeSelected(nodeId));
          },
        ),
      ),
    );
  }

  Widget _buildNodeMap(BuildContext context) {
    return _GlassCard(
      child: NodeMap(
        nodes: state.nodes,
        selectedNode: state.selectedNode,
        onNodeTap: (node) =>
            context.read<KpiBloc>().add(NodeSelected(node.nodeId)),
      ),
    );
  }

  Widget _buildPredictionGauge() {
    return BlocBuilder<PredictionBloc, PredictionState>(
      builder: (context, predState) {
        if (predState is PredictionLoaded) {
          final matchesSelectedNode =
              predState.prediction?.nodeId == state.selectedNode?.nodeId;
          return FaultGauge(
            prediction: matchesSelectedNode ? predState.prediction : null,
            metrics: state.metrics,
            predictionSource:
                matchesSelectedNode ? predState.predictionSource : null,
            modelApiAvailable: matchesSelectedNode &&
                predState.modelApiOnline &&
                predState.modelLoaded,
            statusMessage: matchesSelectedNode || predState.prediction == null
                ? predState.statusMessage
                : 'Loading prediction for ${state.selectedNode?.nodeName ?? 'selected node'}',
            modelF1Score: predState.modelF1Score,
            onRetry: state.selectedNode == null
                ? null
                : () => context
                    .read<PredictionBloc>()
                    .add(PredictionStarted(state.selectedNode!.nodeId)),
          );
        }
        return FaultGauge(
          prediction: null,
          metrics: state.metrics,
          modelApiAvailable: false,
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_AppColors.accent, Color(0xFF7C3AED)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: _AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 6)
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.textPrimary,
                    letterSpacing: -0.2)),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 11, color: _AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  final KpiLoaded state;
  const _Sidebar({required this.state});

  @override
  Widget build(BuildContext context) {
    final healthy =
        state.nodes.where((n) => n.status == NodeStatus.healthy).length;
    final warning =
        state.nodes.where((n) => n.status == NodeStatus.warning).length;
    final critical =
        state.nodes.where((n) => n.status == NodeStatus.critical).length;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dns_rounded,
                          size: 16, color: _AppColors.accent),
                      const SizedBox(width: 8),
                      const Text('NETWORK NODES',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _AppColors.textSecondary,
                              letterSpacing: 1.4)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${state.nodes.length}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _AppColors.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatusPill(
                          label: 'Healthy',
                          count: healthy,
                          color: _AppColors.healthy),
                      const SizedBox(width: 6),
                      _StatusPill(
                          label: 'Warn',
                          count: warning,
                          color: _AppColors.warning),
                      const SizedBox(width: 6),
                      _StatusPill(
                          label: 'Crit',
                          count: critical,
                          color: _AppColors.critical),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.nodes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final node = state.nodes[index];
                  return _NodeTile(
                    node: node,
                    selected: state.selectedNode?.nodeId == node.nodeId,
                    onTap: () =>
                        context.read<KpiBloc>().add(NodeSelected(node.nodeId)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusPill(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 5),
          Text('$count',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final NetworkNodeModel node;
  final bool selected;
  final VoidCallback onTap;
  const _NodeTile(
      {required this.node, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(node.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? _AppColors.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? _AppColors.accent.withValues(alpha: 0.3)
                      : Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: [
                          BoxShadow(
                              color: statusColor.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(node.nodeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              color: selected
                                  ? _AppColors.accent
                                  : _AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(node.ipAddress,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: _AppColors.textMuted,
                                  fontFamily: 'monospace')),
                          const SizedBox(width: 6),
                          Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _AppColors.textMuted)),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(node.statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: statusColor.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: _AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.healthy:
        return _AppColors.healthy;
      case NodeStatus.warning:
        return _AppColors.warning;
      case NodeStatus.critical:
        return _AppColors.critical;
      case NodeStatus.unknown:
        return _AppColors.unknown;
    }
  }
}
