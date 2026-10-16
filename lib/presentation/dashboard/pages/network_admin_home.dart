import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../../data/models/network_node_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/kpi_bloc.dart';
import '../bloc/kpi_event.dart';
import '../bloc/kpi_state.dart';
import '../widgets/kpi_line_chart.dart';
import '../widgets/node_map.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _AppColors {
  static const bg = Color(0xFF0A0E17);
  static const surface = Color(0xFF111827);
  static const surfaceAlt = Color(0xFF1A2332);
  static const border = Color(0xFF1F2A3A);
  static const accent = Color(0xFF00E5FF);
  static const healthy = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const critical = Color(0xFFEF4444);
  static const unknown = Color(0xFF64748B);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

class NetworkAdminHome extends StatelessWidget {
  const NetworkAdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => context.read<KpiBloc>()..add(const DashboardStarted()),
      child: const _DashboardShell(),
    );
  }
}

class _DashboardShell extends StatelessWidget {
  const _DashboardShell();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final username =
        authState is AuthAuthenticated ? authState.user.username : 'User';
    final initials = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: _AppColors.bg,
      appBar: _buildAppBar(context, username, initials),
      body: BlocBuilder<KpiBloc, KpiState>(
        builder: (context, state) {
          if (state is KpiLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _AppColors.accent),
            );
          }
          if (state is KpiError) {
            return _ErrorView(message: state.message);
          }
          if (state is KpiLoaded) {
            return _DashboardBody(state: state);
          }
          return const Center(
            child: Text('Initialising...',
                style: TextStyle(color: _AppColors.textSecondary)),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, String username, String initials) {
    return AppBar(
      elevation: 0,
      backgroundColor: _AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: _AppColors.border, width: 1),
      ),
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_AppColors.accent, Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.hub_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NetVision AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: _AppColors.textPrimary,
                ),
              ),
              Text(
                'Network Operations Center',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: _AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _LiveIndicator(),
        const SizedBox(width: 8),
        _UserChip(username: username, initials: initials),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.logout_rounded,
              color: _AppColors.textSecondary, size: 20),
          tooltip: 'Logout',
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _AppColors.healthy.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.healthy.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _AppColors.healthy,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: _AppColors.healthy,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  final String username;
  final String initials;

  const _UserChip({required this.username, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: _AppColors.accent.withOpacity(0.2),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            username,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _AppColors.textPrimary,
            ),
          ),
        ],
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
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _AppColors.critical.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.critical.withOpacity(0.3)),
        ),
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

class _DashboardBody extends StatelessWidget {
  final KpiLoaded state;

  const _DashboardBody({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Sidebar(state: state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _SectionHeader(
                  title: 'Performance Metrics',
                  subtitle: 'Real-time KPI monitoring',
                ),
                const SizedBox(height: 14),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          child: KpiLineChart(
                            title: 'Latency',
                            unit: 'ms',
                            color: _AppColors.accent,
                            metrics: state.seriesFor(MetricType.latency),
                            warningThreshold: 80,
                            criticalThreshold: 120,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MetricCard(
                          child: KpiLineChart(
                            title: 'Jitter',
                            unit: 'ms',
                            color: const Color(0xFFA78BFA),
                            metrics: state.seriesFor(MetricType.jitter),
                            warningThreshold: 30,
                            criticalThreshold: 50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MetricCard(
                          child: KpiLineChart(
                            title: 'Packet Loss',
                            unit: '%',
                            color: const Color(0xFFFB923C),
                            metrics: state.seriesFor(MetricType.packetLoss),
                            warningThreshold: 1.5,
                            criticalThreshold: 3.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'Network Topology',
                  subtitle:
                      '${state.nodes.length} nodes • tap to inspect',
                ),
                const SizedBox(height: 14),
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: NodeMap(
                      nodes: state.nodes,
                      selectedNode: state.selectedNode,
                      onNodeTap: (node) => context
                          .read<KpiBloc>()
                          .add(NodeSelected(node.nodeId)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_AppColors.accent, Color(0xFF7C3AED)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: _AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final Widget child;

  const _MetricCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final KpiLoaded state;

  const _Sidebar({required this.state});

  @override
  Widget build(BuildContext context) {
    final healthy = state.nodes
        .where((n) => n.status == NodeStatus.healthy)
        .length;
    final warning = state.nodes
        .where((n) => n.status == NodeStatus.warning)
        .length;
    final critical = state.nodes
        .where((n) => n.status == NodeStatus.critical)
        .length;

    return Container(
      width: 280,
      color: _AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns_rounded,
                        size: 16, color: _AppColors.accent),
                    const SizedBox(width: 8),
                    const Text(
                      'NETWORK NODES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _AppColors.textSecondary,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${state.nodes.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Status summary
                Row(
                  children: [
                    _StatusPill(
                        label: 'Healthy', count: healthy, color: _AppColors.healthy),
                    const SizedBox(width: 6),
                    _StatusPill(
                        label: 'Warn', count: warning, color: _AppColors.warning),
                    const SizedBox(width: 6),
                    _StatusPill(
                        label: 'Crit', count: critical, color: _AppColors.critical),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _AppColors.border),
          // Node list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.nodes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final node = state.nodes[index];
                final selected =
                    state.selectedNode?.nodeId == node.nodeId;
                return _NodeTile(
                  node: node,
                  selected: selected,
                  onTap: () => context
                      .read<KpiBloc>()
                      .add(NodeSelected(node.nodeId)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final NetworkNodeModel node;
  final bool selected;
  final VoidCallback onTap;

  const _NodeTile({
    required this.node,
    required this.selected,
    required this.onTap,
  });

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
                  ? _AppColors.accent.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? _AppColors.accent.withOpacity(0.35)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Status indicator with glow
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: statusColor.withOpacity(0.3), width: 1),
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
                            color: statusColor.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
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
                      Text(
                        node.nodeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected
                              ? _AppColors.accent
                              : _AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            node.ipAddress,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              node.statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: statusColor.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
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