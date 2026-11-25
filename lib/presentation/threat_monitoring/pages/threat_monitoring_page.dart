import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/threat_feed_item.dart';
import '../../../data/models/user_models.dart';
import '../../../di/service_locator.dart' as di;
import '../../../presentation/auth/bloc/auth_bloc.dart';
import '../../../presentation/auth/bloc/auth_state.dart';
import '../../../services/threat_detection/threat_assessment.dart';
import '../../../services/threat_detection/threat_classifier.dart';
import '../../../services/threat_features/threat_feature_window.dart';
import '../bloc/threat_monitoring_bloc.dart';
import '../bloc/threat_monitoring_event.dart';
import '../bloc/threat_monitoring_state.dart';

class ThreatMonitoringPage extends StatelessWidget {
  final ThreatMonitoringBloc? bloc;
  final bool runSyntheticDemoOnOpen;
  final bool replaySessionActive;

  const ThreatMonitoringPage({
    super.key,
    this.bloc,
    this.runSyntheticDemoOnOpen = false,
    this.replaySessionActive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<ThreatMonitoringBloc>.value(
        value: bloc!,
        child: _ThreatMonitoringView(
          replaySessionActive: replaySessionActive,
        ),
      );
    }
    return BlocProvider<ThreatMonitoringBloc>(
      create: (_) {
        final bloc = di.sl<ThreatMonitoringBloc>()
          ..add(const ThreatMonitoringStarted());
        if (runSyntheticDemoOnOpen) {
          bloc.add(const ThreatDemoReplayRequested());
        }
        return bloc;
      },
      child: _ThreatMonitoringView(
        replaySessionActive: replaySessionActive,
      ),
    );
  }
}

class _ThreatMonitoringView extends StatelessWidget {
  final bool replaySessionActive;

  const _ThreatMonitoringView({
    required this.replaySessionActive,
  });

  @override
  Widget build(BuildContext context) {
    final user = authenticatedUserFrom(context.watch<AuthBloc>().state);
    final isSystemAdmin = user?.role == UserRole.systemAdministrator;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Threat monitoring'),
            Text(
              'Separate from BiLSTM fault anticipation',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: BlocConsumer<ThreatMonitoringBloc, ThreatMonitoringState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.exportedEvidence != current.exportedEvidence,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          } else if (state.exportedEvidence.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Verified ${state.exportedEvidence.length} evidence record(s).',
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final assessments = state.visibleAssessments;
          return Column(
            children: [
              if (replaySessionActive)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Replay session active. The threat model receives its own '
                    'synthetic aggregate-flow windows alongside the fault '
                    'model KPI sequence; KPI rows are not misrepresented as '
                    'network flows.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              _CategoryFilter(
                value: state.categoryFilter,
                onChanged: (label) => context
                    .read<ThreatMonitoringBloc>()
                    .add(ThreatCategoryFilterChanged(label)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'No production flow collector is connected.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: state.demoRunning
                          ? null
                          : () => context
                              .read<ThreatMonitoringBloc>()
                              .add(const ThreatDemoReplayRequested()),
                      icon: state.demoRunning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(state.demoRunning
                          ? 'Running cloud demo'
                          : 'Run synthetic demo'),
                    ),
                  ],
                ),
              ),
              if (state.demoAssessments.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'SIMULATION ONLY • Synthetic flow windows are sent to the '
                    'cloud threat model and evaluated by local rules. Inputs '
                    'and assessments are not persisted; model-detected '
                    'anomalies create clearly labeled [SIMULATION] alerts. '
                    'This is not production detection.',
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              if (state.errorMessage != null && assessments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11),
                  ),
                ),
              if (state.status == ThreatMonitoringStatus.loading &&
                  assessments.isEmpty)
                const LinearProgressIndicator(),
              Expanded(
                child: assessments.isNotEmpty
                    ? ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: assessments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _ThreatAssessmentCard(
                          assessment: assessments[index],
                          canExportEvidence: isSystemAdmin &&
                              !assessments[index].isSyntheticDemo,
                        ),
                      )
                    : switch (state.status) {
                        ThreatMonitoringStatus.initial ||
                        ThreatMonitoringStatus.loading =>
                          const Center(child: CircularProgressIndicator()),
                        ThreatMonitoringStatus.failure => _MessageView(
                            icon: Icons.error_outline,
                            message: state.errorMessage ??
                                'Threat data could not be loaded.',
                          ),
                        ThreatMonitoringStatus.loaded => const _MessageView(
                            icon: Icons.shield_outlined,
                            message:
                                'No threat assessments have been ingested. '
                                'Run the synthetic demo or connect a normalized '
                                'aggregate-flow producer; raw packet payloads '
                                'are not collected.',
                          ),
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModelPredictionSummary extends StatelessWidget {
  final ThreatClassifierResult prediction;

  const _ModelPredictionSummary({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final category = prediction.label.wireValue.replaceAll('_', ' ');
    final risk = prediction.riskWithinForecastHorizon;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.lightBlueAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLOUD THREAT MODEL • SIMULATION ONLY',
            style: TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Model result: $category'
            '${prediction.label == ThreatLabel.unknown ? ' (abstained)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            prediction.label == ThreatLabel.unknown
                ? 'Confidence withheld'
                : 'Confidence ${(prediction.confidence * 100).toStringAsFixed(1)}%',
          ),
          if (risk != null)
            Text(
              'Synthetic 10-minute availability risk '
              '${(risk * 100).toStringAsFixed(1)}%',
            ),
          Text('Model ${prediction.modelVersion}'),
          if (prediction.uncertaintyReason != null)
            Text(
              prediction.uncertaintyReason!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final ThreatLabel? value;
  final ValueChanged<ThreatLabel?> onChanged;

  const _CategoryFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DropdownButtonFormField<String>(
        initialValue: value?.wireValue ?? 'ALL',
        decoration: const InputDecoration(
          labelText: 'Threat category',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: 'ALL', child: Text('All categories')),
          for (final category in ThreatLabel.values)
            DropdownMenuItem(
              value: category.wireValue,
              child: Text(_categoryLabel(category.wireValue)),
            ),
        ],
        onChanged: (selected) {
          onChanged(selected == null || selected == 'ALL'
              ? null
              : ThreatLabel.values.firstWhere(
                  (label) => label.wireValue == selected,
                ));
        },
      ),
    );
  }
}

class _ThreatAssessmentCard extends StatelessWidget {
  final ThreatFeedItem assessment;
  final bool canExportEvidence;

  const _ThreatAssessmentCard({
    required this.assessment,
    required this.canExportEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(assessment.category);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (assessment.isSyntheticDemo)
                  const Chip(
                    avatar: Icon(Icons.science_outlined,
                        color: Colors.lightBlueAccent, size: 18),
                    label: Text('Synthetic demo'),
                  ),
                Chip(
                  avatar: Icon(_categoryIcon(assessment.category),
                      color: color, size: 18),
                  label: Text(_categoryLabel(assessment.category)),
                  side: BorderSide(color: color.withValues(alpha: 0.6)),
                ),
                Text(
                  assessment.confidence == null
                      ? 'Confidence not available'
                      : 'Confidence ${(assessment.confidence! * 100).toStringAsFixed(1)}%',
                ),
                Chip(label: Text(assessment.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${assessment.nodeId} / ${assessment.serviceId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Observed ${_utc(assessment.observationStart)} – '
              '${_utc(assessment.observationEnd)}',
            ),
            if (assessment.uncertaintyReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  assessment.uncertaintyReason!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (assessment.modelPrediction != null)
              _ModelPredictionSummary(
                prediction: assessment.modelPrediction!,
              ),
            if (assessment.measurements.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Contributing measurements',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final measurement in assessment.measurements.take(5))
                Text(
                  '${measurement['name']}: '
                  '${measurement['observedValue']} '
                  '(baseline ${measurement['baselineValue']}, '
                  '${measurement['direction']})',
                ),
            ],
            const SizedBox(height: 8),
            Text(
              'Service-health corroboration: '
              '${assessment.corroboratedByServiceHealth ? 'Yes' : 'No'}',
            ),
            Text(
              'Recommended check: '
              '${_actionLabel(assessment.recommendedAction)}',
            ),
            if (assessment.dataQualityFlags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Data quality: ${assessment.dataQualityFlags.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (assessment.evidenceLinks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Evidence: ${assessment.evidenceLinks.map((link) => link.evidenceId).join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (assessment.isSyntheticDemo)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Simulation-only result. Acknowledge, resolve, and evidence '
                  'export are disabled for synthetic records.',
                  style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                ),
              )
            else ...[
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  if (assessment.status == 'Open')
                    TextButton(
                      onPressed: () => _recordLifecycle(
                        context,
                        'acknowledged',
                        'Acknowledged by the operator.',
                        nextStatus: 'Acknowledged',
                      ),
                      child: const Text('Acknowledge'),
                    ),
                  if (assessment.status == 'Open' ||
                      assessment.status == 'Acknowledged')
                    TextButton(
                      onPressed: () => _resolve(context),
                      child: const Text('Resolve'),
                    ),
                  if (canExportEvidence)
                    TextButton.icon(
                      onPressed: () => context
                          .read<ThreatMonitoringBloc>()
                          .add(ThreatEvidenceExportRequested(assessment.id)),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Verify evidence'),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => _showDetails(context),
                child: const Text('Details and dismissal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(BuildContext context) async {
    _recordLifecycle(
      context,
      'resolved',
      'Resolved by the operator.',
      nextStatus: 'Resolved',
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    _recordLifecycle(
      context,
      'recommendation_displayed',
      'Operator opened threat assessment details.',
    );
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Threat assessment details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${_categoryLabel(assessment.category)}'),
            Text('Node: ${assessment.nodeId}'),
            Text('Service: ${assessment.serviceId}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Dismissal reason (if dismissing)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Dismiss with reason'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason != null && context.mounted) {
      _recordLifecycle(
        context,
        'dismissed',
        reason,
        nextStatus: 'Dismissed',
      );
    }
  }

  void _recordLifecycle(
    BuildContext context,
    String eventType,
    String details, {
    String? nextStatus,
  }) {
    context.read<ThreatMonitoringBloc>().add(ThreatLifecycleRequested(
          assessment: assessment,
          eventType: eventType,
          details: details,
          nextStatus: nextStatus,
        ));
  }

  String _utc(DateTime value) =>
      DateFormat("yyyy-MM-dd HH:mm:ss 'UTC'").format(value.toUtc());
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

String _categoryLabel(String category) => switch (category) {
      'BENIGN' => 'Benign',
      'AVAILABILITY_ANOMALY' => 'Availability anomaly',
      'OPERATIONAL_FAULT' => 'Operational fault',
      _ => 'Unknown / abstain',
    };

Color _categoryColor(String category) => switch (category) {
      'BENIGN' => Colors.green,
      'AVAILABILITY_ANOMALY' => Colors.deepOrange,
      'OPERATIONAL_FAULT' => Colors.amber,
      _ => Colors.blueGrey,
    };

IconData _categoryIcon(String category) => switch (category) {
      'BENIGN' => Icons.check_circle_outline,
      'AVAILABILITY_ANOMALY' => Icons.warning_amber_rounded,
      'OPERATIONAL_FAULT' => Icons.build_circle_outlined,
      _ => Icons.help_outline,
    };

String _actionLabel(String action) => switch (action) {
      'verifyServiceHealth' => SafeNextStep.verifyServiceHealth.label,
      'checkUpstreamMitigationStatus' =>
        SafeNextStep.checkUpstreamMitigationStatus.label,
      'reviewRecentChanges' => SafeNextStep.reviewRecentChanges.label,
      'preserveLogs' => SafeNextStep.preserveLogs.label,
      'escalateIncident' => SafeNextStep.escalateIncident.label,
      _ => action,
    };
