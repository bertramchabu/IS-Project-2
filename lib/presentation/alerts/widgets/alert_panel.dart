import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/alert_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/alert_bloc.dart';
import '../bloc/alert_event.dart';
import '../bloc/alert_state.dart';

class AlertPanel extends StatelessWidget {
  final double? width;
  final VoidCallback? onClose;

  const AlertPanel({super.key, this.width = 340, this.onClose});

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF1F2A3A);

    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xD9101827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x667E9BBF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const Divider(height: 1, color: borderColor),
                Expanded(
                  child: BlocConsumer<AlertBloc, AlertState>(
                    listener: (context, state) {
                      if (state is AlertActionSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    color: Color(0xFF22C55E), size: 18),
                                const SizedBox(width: 8),
                                Text(state.message),
                              ],
                            ),
                            backgroundColor: const Color(0xFF1F2A3A),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (state is AlertError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      if (state is AlertLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E5FF),
                            strokeWidth: 2,
                          ),
                        );
                      }
                      if (state is AlertError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xFFEF4444), fontSize: 12),
                            ),
                          ),
                        );
                      }
                      if (state is AlertLoaded) {
                        final alerts = state.filteredAlerts;
                        if (alerts.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 40, color: Color(0xFF22C55E)),
                                SizedBox(height: 8),
                                Text(
                                  'No active alerts',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'All network nodes operating nominally',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: alerts.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0x332F4058),
                          ),
                          itemBuilder: (context, index) => _AlertTile(
                            alert: alerts[index],
                            onAcknowledge: () {
                              final authState = context.read<AuthBloc>().state;
                              if (authState is AuthAuthenticated) {
                                context.read<AlertBloc>().add(
                                      AlertAcknowledged(
                                        alertId: alerts[index].alertId,
                                        userId: authState.user.userId,
                                      ),
                                    );
                              }
                            },
                            onDismiss: () => _showDismissDialog(
                              context,
                              alerts[index].alertId,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: BlocBuilder<AlertBloc, AlertState>(
        builder: (context, state) {
          final count = state is AlertLoaded ? state.activeCount : 0;
          final critical = state is AlertLoaded ? state.criticalCount : 0;

          return Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              const Text(
                'LIVE ALERTS',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Color(0xFFF1F5F9),
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: critical > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              const Spacer(),
              PopupMenuButton<AlertStatus?>(
                icon: const Icon(Icons.filter_list_rounded,
                    size: 18, color: Color(0xFF94A3B8)),
                tooltip: 'Filter by Status',
                color: const Color(0xFF1A2332),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF1F2A3A)),
                ),
                onSelected: (filter) => context
                    .read<AlertBloc>()
                    .add(AlertStatusFilterChanged(filter)),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: null,
                    child: Text('All Alerts',
                        style:
                            TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: AlertStatus.active,
                    child: Text('Active Only',
                        style:
                            TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: AlertStatus.acknowledged,
                    child: Text('Acknowledged',
                        style:
                            TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: AlertStatus.dismissed,
                    child: Text('Dismissed',
                        style:
                            TextStyle(color: Color(0xFFF1F5F9), fontSize: 13)),
                  ),
                ],
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close alerts',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showDismissDialog(BuildContext context, String alertId) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF1F2A3A)),
          ),
          title: const Row(
            children: [
              Icon(Icons.remove_circle_outline,
                  color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Dismiss Alert',
                style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Dismissal Reason',
              labelStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              hintText: 'e.g. Scheduled maintenance window',
              hintStyle:
                  const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1A2332),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1F2A3A)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8)),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) return;
                final authState = context.read<AuthBloc>().state;
                if (authState is AuthAuthenticated) {
                  context.read<AlertBloc>().add(AlertDismissed(
                        alertId: alertId,
                        userId: authState.user.userId,
                        reason: reason,
                      ));
                }
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Dismiss Alert'),
            ),
          ],
        );
      },
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onAcknowledge;
  final VoidCallback onDismiss;

  const _AlertTile({
    required this.alert,
    required this.onAcknowledge,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final sevColor = _severityColor(alert.severity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sevColor.withOpacity(0.06),
        border: Border(
          left: BorderSide(color: sevColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sevColor.withOpacity(0.5)),
                ),
                child: Text(
                  alert.severityLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: sevColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.nodeName ?? alert.nodeId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF1F5F9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatTime(alert.createdAt),
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            alert.description,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (alert.isActive) ...[
                OutlinedButton.icon(
                  onPressed: onAcknowledge,
                  icon: const Icon(Icons.check_rounded, size: 13),
                  label: const Text('Ack', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF22C55E),
                    side:
                        const BorderSide(color: Color(0xFF22C55E), width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 26),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 13),
                  label: const Text('Dismiss', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side:
                        const BorderSide(color: Color(0xFF1F2A3A), width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 26),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ] else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF1F2A3A)),
                  ),
                  child: Text(
                    alert.statusLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return const Color(0xFF22C55E);
      case AlertSeverity.medium:
        return const Color(0xFFF59E0B);
      case AlertSeverity.high:
        return const Color(0xFFFB923C);
      case AlertSeverity.critical:
        return const Color(0xFFEF4444);
    }
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM HH:mm').format(t);
  }
}
