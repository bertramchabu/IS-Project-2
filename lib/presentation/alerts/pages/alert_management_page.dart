import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_error_logger.dart';
import '../../../core/utils/csv_util.dart';
import '../../../core/utils/platform_actions.dart';
import '../../../data/models/alert_model.dart';
import '../../../di/service_locator.dart' as di;
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/alert_bloc.dart';
import '../bloc/alert_event.dart';
import '../bloc/alert_state.dart';
import '../../../services/alert_audio.dart';

enum _AlertSort { newest, oldest, severity }

class AlertManagementPage extends StatefulWidget {
  const AlertManagementPage({super.key});

  @override
  State<AlertManagementPage> createState() => _AlertManagementPageState();
}

class _AlertManagementPageState extends State<AlertManagementPage> {
  static const _bg = Color(0xFF0A0E17);
  static const _surface = Color(0xB3111827);
  static const _surfaceAlt = Color(0xAA1A2332);
  static const _border = Color(0x526A7D98);
  static const _accent = Color(0xFF00E5FF);
  static const _healthy = Color(0xFF22C55E);
  static const _warning = Color(0xFFF59E0B);
  static const _critical = Color(0xFFEF4444);
  static const _textPrimary = Color(0xFFF1F5F9);
  static const _textSecondary = Color(0xFF94A3B8);
  static const _textMuted = Color(0xFF64748B);

  final _searchController = TextEditingController();
  final _selectedAlerts = <String>{};
  _AlertSort _sort = _AlertSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ({String userId, String userName}) _currentUser() {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    return (
      userId: user?.userId ?? 'unknown',
      userName: user?.username ?? 'unknown',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlertBloc>(
      create: (_) => di.sl<AlertBloc>()..add(const AlertsStarted()),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xCC111827),
          surfaceTintColor: Colors.transparent,
          shape: const Border(bottom: BorderSide(color: _border, width: 1)),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: _warning, size: 20),
              SizedBox(width: 10),
              Text(
                'Alert Management',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: AlertAudio.enabled
                  ? 'Audio alerts on'
                  : 'Audio alerts off (click to enable)',
              icon: Icon(
                AlertAudio.enabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: AlertAudio.enabled ? _healthy : _textMuted,
                size: 20,
              ),
              onPressed: () async {
                if (AlertAudio.enabled) {
                  setState(() => AlertAudio.enabled = false);
                  return;
                }
                // The click itself is the audio gesture browsers require.
                final messenger = ScaffoldMessenger.of(context);
                await playAlertChime();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Audio alerts enabled'),
                    backgroundColor: _healthy,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() => AlertAudio.enabled = true);
              },
            ),
            IconButton(
              tooltip: 'Export visible alerts to CSV',
              icon:
                  const Icon(Icons.download_rounded, color: _accent, size: 20),
              onPressed: () => _exportCsv(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocConsumer<AlertBloc, AlertState>(
          listenWhen: (previous, current) =>
              current is AlertActionSuccess ||
              current is AlertError ||
              (current is AlertLoaded &&
                  previous is AlertLoaded &&
                  current.criticalCount > previous.criticalCount),
          listener: (context, state) {
            // Chime on a rising number of active critical alerts (FR-AS-02).
            if (state is AlertLoaded) AlertAudio.chime();
            if (state is AlertActionSuccess) {
              _selectedAlerts.clear();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: _healthy,
                behavior: SnackBarBehavior.floating,
              ));
            } else if (state is AlertError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: _critical,
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
          builder: (context, state) {
            if (state is! AlertLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: _accent),
              );
            }

            final visible = _sorted(state.filteredAlerts, context);
            final activeIds = state.activeAlerts.map((a) => a.alertId).toSet();
            _selectedAlerts.removeWhere((id) => !activeIds.contains(id));

            return Column(
              children: [
                _statsRow(state),
                _filterBar(context, state),
                if (_selectedAlerts.isNotEmpty) _bulkBar(context, state),
                Expanded(
                  child: visible.isEmpty
                      ? _emptyState()
                      : _alertList(context, visible),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<AlertModel> _sorted(List<AlertModel> alerts, BuildContext context) {
    final sorted = [...alerts];
    switch (_sort) {
      case _AlertSort.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _AlertSort.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _AlertSort.severity:
        sorted.sort((a, b) {
          final bySeverity = b.severity.index.compareTo(a.severity.index);
          return bySeverity != 0
              ? bySeverity
              : b.createdAt.compareTo(a.createdAt);
        });
    }
    return sorted;
  }

  Widget _statsRow(AlertLoaded state) {
    final counts = state.statusCounts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _statCard('ACTIVE', state.activeCount, _warning),
          _statCard('CRITICAL', state.criticalCount, _critical),
          _statCard(
              'ACKNOWLEDGED', counts[AlertStatus.acknowledged] ?? 0, _accent),
          _statCard(
              'DISMISSED', counts[AlertStatus.dismissed] ?? 0, _textMuted),
          _statCard('RESOLVED', counts[AlertStatus.resolved] ?? 0, _healthy),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: color)),
          Text('$count',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _filterBar(BuildContext context, AlertLoaded state) {
    final bloc = context.read<AlertBloc>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 6,
            children: [
              _statusChip(context, 'ALL', null, state.statusFilter),
              ...AlertStatus.values.map((status) => _statusChip(
                    context,
                    status.name.toUpperCase(),
                    status,
                    state.statusFilter,
                  )),
            ],
          ),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: DropdownButton<AlertSeverity?>(
                value: state.severityFilter,
                dropdownColor: _surfaceAlt,
                hint: const Text('Severity',
                    style: TextStyle(color: _textSecondary, fontSize: 12)),
                items: [
                  const DropdownMenuItem<AlertSeverity?>(
                      value: null,
                      child: Text('All severities',
                          style: TextStyle(color: _textPrimary, fontSize: 12))),
                  ...AlertSeverity.values.map((s) =>
                      DropdownMenuItem<AlertSeverity?>(
                          value: s,
                          child: Text(s.name.toUpperCase(),
                              style: const TextStyle(
                                  color: _textPrimary, fontSize: 12)))),
                ],
                onChanged: (value) =>
                    bloc.add(AlertSeverityFilterChanged(value)),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: DropdownButton<String?>(
                value: state.nodeFilter,
                dropdownColor: _surfaceAlt,
                hint: const Text('Node',
                    style: TextStyle(color: _textSecondary, fontSize: 12)),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All nodes',
                          style: TextStyle(color: _textPrimary, fontSize: 12))),
                  ...state.nodeOptions.map((node) => DropdownMenuItem<String?>(
                      value: node,
                      child: Text(node,
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 12)))),
                ],
                onChanged: (value) => bloc.add(AlertNodeFilterChanged(value)),
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: DropdownButton<_AlertSort>(
                value: _sort,
                dropdownColor: _surfaceAlt,
                items: const [
                  DropdownMenuItem(
                      value: _AlertSort.newest,
                      child: Text('Newest first',
                          style: TextStyle(color: _textPrimary, fontSize: 12))),
                  DropdownMenuItem(
                      value: _AlertSort.oldest,
                      child: Text('Oldest first',
                          style: TextStyle(color: _textPrimary, fontSize: 12))),
                  DropdownMenuItem(
                      value: _AlertSort.severity,
                      child: Text('By severity',
                          style: TextStyle(color: _textPrimary, fontSize: 12))),
                ],
                onChanged: (value) =>
                    setState(() => _sort = value ?? _AlertSort.newest),
              ),
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: _textPrimary, fontSize: 12.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search alerts…',
                hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _textMuted, size: 18),
                filled: true,
                fillColor: _surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => bloc.add(AlertQueryChanged(value)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label, AlertStatus? value,
      AlertStatus? selected) {
    final bloc = context.read<AlertBloc>();
    final active = value == selected;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: active ? _bg : _textSecondary)),
      selected: active,
      showCheckmark: false,
      backgroundColor: _surfaceAlt,
      selectedColor: _accent,
      side: const BorderSide(color: _border),
      onSelected: (_) => bloc.add(AlertStatusFilterChanged(value)),
    );
  }

  Widget _bulkBar(BuildContext context, AlertLoaded state) {
    final selected =
        state.alerts.where((a) => _selectedAlerts.contains(a.alertId)).toList();
    final allVisibleSelected = _allVisibleSelected(state);
    void acknowledgeSelected() {
      final user = _currentUser();
      context.read<AlertBloc>().add(AlertsBulkAcknowledged(
          alerts: selected, userId: user.userId, userName: user.userName));
    }

    final checkbox = Checkbox(
      value: allVisibleSelected,
      tristate: true,
      activeColor: _accent,
      onChanged: (_) => _toggleSelectAll(context, state),
    );
    final selectionCount = Text('${selected.length} selected',
        style: const TextStyle(
            color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600));
    final acknowledgeButton = TextButton.icon(
      onPressed: acknowledgeSelected,
      icon: const Icon(Icons.done_all_rounded, size: 18, color: _accent),
      label: const Text('Acknowledge all selected',
          style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
    );
    final clearButton = TextButton(
      onPressed: () => setState(_selectedAlerts.clear),
      child: const Text('Clear', style: TextStyle(color: _textMuted)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                checkbox,
                selectionCount,
                acknowledgeButton,
                clearButton,
              ],
            );
          }
          return Row(
            children: [
              checkbox,
              selectionCount,
              const Spacer(),
              acknowledgeButton,
              clearButton,
            ],
          );
        },
      ),
    );
  }

  bool _allVisibleSelected(AlertLoaded state) {
    final activeVisible =
        state.filteredAlerts.where((a) => a.isActive).toList();
    if (activeVisible.isEmpty) return false;
    return activeVisible.every((a) => _selectedAlerts.contains(a.alertId));
  }

  void _toggleSelectAll(BuildContext context, AlertLoaded state) {
    final activeVisible =
        state.filteredAlerts.where((a) => a.isActive).toList();
    setState(() {
      if (_allVisibleSelected(state)) {
        _selectedAlerts.removeAll(activeVisible.map((a) => a.alertId));
      } else {
        _selectedAlerts.addAll(activeVisible.map((a) => a.alertId));
      }
    });
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 44, color: _healthy),
          SizedBox(height: 10),
          Text('No alerts match the current filters',
              style: TextStyle(color: _textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _alertList(BuildContext context, List<AlertModel> alerts) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
      itemBuilder: (context, index) => _alertRow(context, alerts[index]),
    );
  }

  Widget _alertRow(BuildContext context, AlertModel alert) {
    final severityColor = switch (alert.severity) {
      AlertSeverity.critical => _critical,
      AlertSeverity.high => _warning,
      AlertSeverity.medium => _accent,
      AlertSeverity.low => _textMuted,
    };
    final timeFormat = DateFormat('dd MMM HH:mm:ss');

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return _compactAlertRow(context, alert, severityColor, timeFormat);
        }

        return InkWell(
          onTap: () => _showDetailsDialog(context, alert),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (alert.isActive)
                  Checkbox(
                    value: _selectedAlerts.contains(alert.alertId),
                    activeColor: _accent,
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedAlerts.add(alert.alertId);
                      } else {
                        _selectedAlerts.remove(alert.alertId);
                      }
                    }),
                  )
                else
                  const SizedBox(width: 34),
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.nodeName ?? alert.nodeId,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.description,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: Text(alert.severityLabel,
                      style: TextStyle(
                          color: severityColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ),
                SizedBox(
                  width: 110,
                  child: Text(alert.statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _alertStatusColor(alert.status))),
                ),
                SizedBox(
                  width: 130,
                  child: Text(timeFormat.format(alert.createdAt.toLocal()),
                      style: const TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ),
                _rowActions(context, alert),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _compactAlertRow(
    BuildContext context,
    AlertModel alert,
    Color severityColor,
    DateFormat timeFormat,
  ) {
    return InkWell(
      onTap: () => _showDetailsDialog(context, alert),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (alert.isActive)
                  Checkbox(
                    value: _selectedAlerts.contains(alert.alertId),
                    activeColor: _accent,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedAlerts.add(alert.alertId);
                      } else {
                        _selectedAlerts.remove(alert.alertId);
                      }
                    }),
                  )
                else
                  const SizedBox(width: 40),
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.nodeName ?? alert.nodeId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  alert.severityLabel,
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 54, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          alert.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _alertStatusColor(alert.status),
                          ),
                        ),
                        Text(
                          timeFormat.format(alert.createdAt.toLocal()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _compactRowActions(context, alert),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactRowActions(BuildContext context, AlertModel alert) {
    if (!alert.isActive && alert.status != AlertStatus.acknowledged) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Alert actions',
      onSelected: (action) {
        final bloc = context.read<AlertBloc>();
        final user = _currentUser();
        switch (action) {
          case 'acknowledge':
            bloc.add(AlertAcknowledged(
              nodeId: alert.nodeId,
              alertId: alert.alertId,
              userId: user.userId,
              userName: user.userName,
            ));
            break;
          case 'dismiss':
            _showDismissDialog(context, alert);
            break;
          case 'resolve':
            bloc.add(AlertResolved(
              nodeId: alert.nodeId,
              alertId: alert.alertId,
              userId: user.userId,
              userName: user.userName,
            ));
            break;
        }
      },
      itemBuilder: (context) => [
        if (alert.isActive) ...[
          const PopupMenuItem(
            value: 'acknowledge',
            child: Text('Acknowledge'),
          ),
          const PopupMenuItem(
            value: 'dismiss',
            child: Text('Dismiss as false positive'),
          ),
        ] else
          const PopupMenuItem(
            value: 'resolve',
            child: Text('Resolve'),
          ),
      ],
      icon: const Icon(Icons.more_vert_rounded, color: _textSecondary),
    );
  }

  Color _alertStatusColor(AlertStatus status) => switch (status) {
        AlertStatus.active => _warning,
        AlertStatus.acknowledged => _accent,
        AlertStatus.dismissed => _textMuted,
        AlertStatus.resolved => _healthy,
      };

  Widget _rowActions(BuildContext context, AlertModel alert) {
    final bloc = context.read<AlertBloc>();
    final user = _currentUser();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (alert.isActive) ...[
          IconButton(
            tooltip: 'Acknowledge',
            icon: const Icon(Icons.check_circle_outline_rounded,
                size: 18, color: _accent),
            onPressed: () => bloc.add(AlertAcknowledged(
              nodeId: alert.nodeId,
              alertId: alert.alertId,
              userId: user.userId,
              userName: user.userName,
            )),
          ),
          IconButton(
            tooltip: 'Dismiss as false positive',
            icon: const Icon(Icons.block_rounded, size: 18, color: _warning),
            onPressed: () => _showDismissDialog(context, alert),
          ),
        ] else if (alert.status == AlertStatus.acknowledged)
          IconButton(
            tooltip: 'Resolve',
            icon: const Icon(Icons.policy_outlined, size: 18, color: _healthy),
            onPressed: () => bloc.add(AlertResolved(
              nodeId: alert.nodeId,
              alertId: alert.alertId,
              userId: user.userId,
              userName: user.userName,
            )),
          ),
      ],
    );
  }

  void _showDismissDialog(BuildContext context, AlertModel alert) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _border),
          ),
          title: const Text('Dismiss alert',
              style: TextStyle(color: _textPrimary, fontSize: 16)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A reason is required so false positives stay auditable '
                  '(FR-NA-08).',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    filled: true,
                    fillColor: _surfaceAlt,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                final user = _currentUser();
                ctx.read<AlertBloc>().add(AlertDismissed(
                      nodeId: alert.nodeId,
                      alertId: alert.alertId,
                      userId: user.userId,
                      userName: user.userName,
                      reason: reason,
                    ));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _warning,
                foregroundColor: _bg,
              ),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }

  void _showDetailsDialog(BuildContext context, AlertModel alert) {
    final fullTime = DateFormat('dd MMM yyyy  HH:mm:ss');
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _border),
          ),
          title: Text(alert.title,
              style: const TextStyle(color: _textPrimary, fontSize: 15.5)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Node', alert.nodeName ?? alert.nodeId),
                _detailRow('Severity', alert.severityLabel),
                _detailRow('Status', alert.statusLabel),
                _detailRow(
                    'Raised', fullTime.format(alert.createdAt.toLocal())),
                if (alert.acknowledgedAt != null)
                  _detailRow('Acknowledged',
                      fullTime.format(alert.acknowledgedAt!.toLocal())),
                if (alert.acknowledgedBy != null)
                  _detailRow('By', alert.acknowledgedBy!),
                if (alert.resolvedAt != null)
                  _detailRow(
                      'Resolved', fullTime.format(alert.resolvedAt!.toLocal())),
                if (alert.dismissalReason != null)
                  _detailRow('Dismissal reason', alert.dismissalReason!),
                if (alert.predictionId != null)
                  _detailRow('Prediction', alert.predictionId!),
                const SizedBox(height: 8),
                Text(alert.description,
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 12.5, height: 1.5)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: _textMuted)),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: _textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final state = context.read<AlertBloc>().state;
    if (state is! AlertLoaded) return;
    final rows = state.filteredAlerts
        .map((a) => {
              'alertId': a.alertId,
              'node': a.nodeName ?? a.nodeId,
              'severity': a.severityLabel,
              'status': a.statusLabel,
              'title': a.title,
              'description': a.description,
              'acknowledgedBy': a.acknowledgedBy ?? '',
              'dismissalReason': a.dismissalReason ?? '',
              'createdAt': a.createdAt.toIso8601String(),
            })
        .toList();
    try {
      final path = await downloadCsv(
          timestampFileName('netvision_alerts'), encodeCsv(rows));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported ${rows.length} alerts to $path'),
          backgroundColor: _healthy,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      AppErrorLogger.log('AlertManagementPage.exportCsv', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: _critical,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
