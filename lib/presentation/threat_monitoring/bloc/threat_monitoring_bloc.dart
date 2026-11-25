import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_error_logger.dart';
import '../../../data/models/threat_feed_item.dart';
import '../../../data/repositories/alert_repository.dart';
import '../../../data/repositories/threat_repository.dart';
import '../../../services/threat_features/threat_demo_replay.dart';
import '../../../services/threat_features/threat_feature_window.dart';
import 'threat_monitoring_event.dart';
import 'threat_monitoring_state.dart';

class ThreatMonitoringBloc
    extends Bloc<ThreatMonitoringEvent, ThreatMonitoringState> {
  final ThreatRepository _repository;
  final AlertRepository _alerts;
  final ThreatDemoReplay _demoReplay;
  StreamSubscription<dynamic>? _assessmentSubscription;

  ThreatMonitoringBloc(
    this._repository, {
    required AlertRepository alerts,
    ThreatDemoReplay? demoReplay,
  })  : _alerts = alerts,
        _demoReplay = demoReplay ?? ThreatDemoReplay(),
        super(const ThreatMonitoringState()) {
    on<ThreatMonitoringStarted>(_onStarted);
    on<ThreatDemoReplayRequested>(_onDemoReplayRequested);
    on<ThreatCategoryFilterChanged>((event, emit) {
      emit(state.copyWith(
        categoryFilter: event.category,
        clearCategoryFilter: event.category == null,
      ));
    });
    on<ThreatLifecycleRequested>(_onLifecycleRequested);
    on<ThreatEvidenceExportRequested>(_onEvidenceExportRequested);
    on<ThreatAssessmentsReceived>((event, emit) {
      emit(state.copyWith(
        status: ThreatMonitoringStatus.loaded,
        assessments: event.assessments,
        clearError: true,
      ));
    });
    on<ThreatAssessmentsFailed>((event, emit) {
      emit(state.copyWith(
        status: ThreatMonitoringStatus.failure,
        errorMessage: event.message,
      ));
    });
  }

  Future<void> _onStarted(
    ThreatMonitoringStarted event,
    Emitter<ThreatMonitoringState> emit,
  ) async {
    emit(state.copyWith(
        status: ThreatMonitoringStatus.loading, clearError: true));
    await _assessmentSubscription?.cancel();
    _assessmentSubscription = _repository.watchAssessments().listen(
      (assessments) => add(ThreatAssessmentsReceived(assessments)),
      onError: (Object error) {
        AppErrorLogger.log('ThreatMonitoringBloc.assessmentStream', error);
        final message = switch (error) {
          FirebaseException() => 'Could not load threat assessments '
              '(${error.code}): ${error.message ?? error.code}'
              '${error.code == 'permission-denied' ? ' '
                  'This feed requires an active Network or System Administrator profile; '
                  'verify the deployed Firestore rules and user roleId.' : ''}',
          _ => 'Could not load threat assessments: $error',
        };
        add(ThreatAssessmentsFailed(message));
      },
    );
  }

  Future<void> _onDemoReplayRequested(
    ThreatDemoReplayRequested event,
    Emitter<ThreatMonitoringState> emit,
  ) async {
    if (state.demoRunning) return;
    emit(state.copyWith(demoRunning: true, clearError: true));
    try {
      final results = await _demoReplay.generate();
      emit(state.copyWith(
        demoAssessments: [
          for (final result in results)
            ThreatFeedItem.fromDemoAssessment(result.assessment),
        ],
      ));
      for (final result in results) {
        final assessment = result.assessment;
        final modelPrediction = assessment.modelPrediction;
        if (modelPrediction == null ||
            (modelPrediction.label != ThreatLabel.availabilityAnomaly &&
                modelPrediction.label != ThreatLabel.operationalFault)) {
          continue;
        }
        await _alerts.raiseThreatModelAlert(
          assessmentId: assessment.assessmentId,
          nodeId: assessment.nodeId,
          serviceId: assessment.serviceId,
          category: modelPrediction.label.wireValue,
          confidence: modelPrediction.confidence,
          riskWithinForecastHorizon: modelPrediction.riskWithinForecastHorizon,
          modelVersionId: modelPrediction.modelVersion,
        );
      }
      emit(state.copyWith(demoRunning: false));
    } catch (error) {
      AppErrorLogger.log('ThreatMonitoringBloc.demoReplay', error);
      emit(state.copyWith(
        demoRunning: false,
        errorMessage: 'Synthetic threat demo failed: $error',
      ));
    }
  }

  Future<void> _onLifecycleRequested(
    ThreatLifecycleRequested event,
    Emitter<ThreatMonitoringState> emit,
  ) async {
    try {
      await _repository.recordLifecycleEvent(
        assessmentId: event.assessment.id,
        eventType: event.eventType,
        details: event.details,
        nextStatus: event.nextStatus,
      );
      emit(state.copyWith(clearError: true));
    } catch (error) {
      AppErrorLogger.log('ThreatMonitoringBloc.lifecycleEvent', error);
      emit(state.copyWith(
        status: ThreatMonitoringStatus.failure,
        errorMessage: 'Could not record threat event: $error',
      ));
    }
  }

  Future<void> _onEvidenceExportRequested(
    ThreatEvidenceExportRequested event,
    Emitter<ThreatMonitoringState> emit,
  ) async {
    try {
      final records = await _repository.exportEvidence(event.assessmentId);
      emit(state.copyWith(exportedEvidence: records, clearError: true));
    } catch (error) {
      AppErrorLogger.log('ThreatMonitoringBloc.evidenceExport', error);
      emit(state.copyWith(
        status: ThreatMonitoringStatus.failure,
        errorMessage: 'Could not export threat evidence: $error',
      ));
    }
  }

  @override
  Future<void> close() async {
    await _assessmentSubscription?.cancel();
    return super.close();
  }
}
