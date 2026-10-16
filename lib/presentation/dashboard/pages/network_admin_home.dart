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
    final authState = context.read<AuthBloc>().state;
    final username = authState is AuthAuthenticated
        ? authState.user.username
        : 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('NetVision AI'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(username,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<KpiBloc, KpiState>(
        builder: (context, state) {
          if (state is KpiLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is KpiError) {
            return Center(
              child: Text('Error: ${state.message}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          if (state is KpiLoaded) {
            return _DashboardBody(state: state);
          }
          return const Center(child: Text('Initialising...'));
        },
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
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // KPI charts row
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: KpiLineChart(
                          title: 'Latency',
                          unit: 'ms',
                          color: Colors.cyanAccent,
                          metrics: state.seriesFor(MetricType.latency),
                          warningThreshold: 80,
                          criticalThreshold: 120,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KpiLineChart(
                          title: 'Jitter',
                          unit: 'ms',
                          color: Colors.purpleAccent,
                          metrics: state.seriesFor(MetricType.jitter),
                          warningThreshold: 30,
                          criticalThreshold: 50,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KpiLineChart(
                          title: 'Packet Loss',
                          unit: '%',
                          color: Colors.orangeAccent,
                          metrics: state.seriesFor(MetricType.packetLoss),
                          warningThreshold: 1.5,
                          criticalThreshold: 3.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Map
                Expanded(
                  flex: 4,
                  child: NodeMap(
                    nodes: state.nodes,
                    selectedNode: state.selectedNode,
                    onNodeTap: (node) => context
                        .read<KpiBloc>()
                        .add(NodeSelected(node.nodeId)),
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

class _Sidebar extends StatelessWidget {
  final KpiLoaded state;

  const _Sidebar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF131A26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('NETWORK NODES',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                    letterSpacing: 1.2)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.nodes.length,
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
    return ListTile(
      selected: selected,
      selectedTileColor: Colors.cyan.withValues(alpha: 0.1),
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _statusColor(node.status),
          boxShadow: [
            BoxShadow(
                color: _statusColor(node.status).withValues(alpha: 0.5),
                blurRadius: 6),
          ],
        ),
      ),
      title: Text(node.nodeName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text('${node.ipAddress} • ${node.statusLabel}',
          style: const TextStyle(fontSize: 11, color: Colors.white54)),
      onTap: onTap,
    );
  }

  Color _statusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.healthy:
        return const Color(0xFF4CAF50);
      case NodeStatus.warning:
        return const Color(0xFFFFC107);
      case NodeStatus.critical:
        return const Color(0xFFF44336);
      case NodeStatus.unknown:
        return Colors.grey;
    }
  }
}