import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/app_error_logger.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';
import '../../../data/repositories/audit_repository.dart';
import 'alert_event.dart';
import 'alert_state.dart';

class AlertBloc extends Bloc<AlertEvent, AlertState> {
  final AlertRepository _repo;
  final AuditRepository? _audit;

  StreamSubscription? _sub;
  AlertStatus? _currentStatusFilter;
  AlertSeverity? _currentSeverityFilter;
  String? _currentNodeFilter;
  String _query = '';

  AlertBloc(this._repo, {AuditRepository? audit})
      : _audit = audit,
        super(const AlertInitial()) {
    on<AlertsStarted>(_onStarted);
    on<AlertStatusFilterChanged>(_onStatusFilterChanged);
    on<AlertSeverityFilterChanged>(_onSeverityFilterChanged);
    on<AlertNodeFilterChanged>(_onNodeFilterChanged);
    on<AlertQueryChanged>(_onQueryChanged);
    on<AlertAcknowledged>(_onAcknowledged);
    on<AlertsBulkAcknowledged>(_onBulkAcknowledged);
    on<AlertResolved>(_onResolved);
    on<AlertDismissed>(_onDismissed);
    on<AlertsReceived>(_onReceived);
    on<AlertStreamError>(_onStreamError);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    AppErrorLogger.log('AlertBloc.unhandled', error);
    super.onError(error, stackTrace);
  }

  Future<void> _onStarted(
    AlertsStarted event,
    Emitter<AlertState> emit,
  ) async {
    await _sub?.cancel();
    _sub = _repo.watchAlerts().listen(
      (alerts) => add(AlertsReceived(alerts)),
      onError: (Object error) {
        AppErrorLogger.log('AlertBloc.stream', error);
        add(AlertStreamError(error.toString()));
      },
    );
  }

  Future<void> _onStatusFilterChanged(
    AlertStatusFilterChanged event,
    Emitter<AlertState> emit,
  ) async {
    _currentStatusFilter = event.filter;
    _emitFiltered(emit);
  }

  Future<void> _onSeverityFilterChanged(
    AlertSeverityFilterChanged event,
    Emitter<AlertState> emit,
  ) async {
    _currentSeverityFilter = event.filter;
    _emitFiltered(emit);
  }

  Future<void> _onNodeFilterChanged(
    AlertNodeFilterChanged event,
    Emitter<AlertState> emit,
  ) async {
    _currentNodeFilter = event.nodeId;
    _emitFiltered(emit);
  }

  Future<void> _onQueryChanged(
    AlertQueryChanged event,
    Emitter<AlertState> emit,
  ) async {
    _query = event.query;
    _emitFiltered(emit);
  }

  void _emitFiltered(Emitter<AlertState> emit) {
    final current = state;
    if (current is AlertLoaded) {
      emit(current.copyWith(
        statusFilter: _currentStatusFilter,
        clearStatusFilter: _currentStatusFilter == null,
        severityFilter: _currentSeverityFilter,
        clearSeverityFilter: _currentSeverityFilter == null,
        nodeFilter: _currentNodeFilter,
        clearNodeFilter: _currentNodeFilter == null,
        query: _query,
      ));
    }
  }

  Future<void> _onReceived(
    AlertsReceived event,
    Emitter<AlertState> emit,
  ) async {
    emit(AlertLoaded(
      alerts: event.alerts,
      statusFilter: _currentStatusFilter,
      severityFilter: _currentSeverityFilter,
      nodeFilter: _currentNodeFilter,
      query: _query,
    ));
  }

  Future<void> _onAcknowledged(
    AlertAcknowledged event,
    Emitter<AlertState> emit,
  ) async {
    try {
      await _repo.acknowledgeAlert(
        event.nodeId,
        event.alertId,
        event.userId,
      );
      await _audit?.log(
        userId: event.userId,
        userName: event.userName,
        action: AuditActions.alertAcknowledged,
        details: 'Acknowledged alert ${event.alertId} on node ${event.nodeId}',
      );
      _succeed(emit, 'Alert acknowledged');
    } catch (e) {
      AppErrorLogger.log('AlertBloc.acknowledge', e);
      emit(AlertError('Failed to acknowledge: ${e.toString()}'));
    }
  }

  Future<void> _onBulkAcknowledged(
    AlertsBulkAcknowledged event,
    Emitter<AlertState> emit,
  ) async {
    var done = 0;
    try {
      for (final alert in event.alerts) {
        await _repo.acknowledgeAlert(
          alert.nodeId,
          alert.alertId,
          event.userId,
        );
        done++;
      }
      await _audit?.log(
        userId: event.userId,
        userName: event.userName,
        action: AuditActions.alertsBulkAcknowledged,
        details: 'Bulk acknowledged $done alert(s)',
      );
      _succeed(emit, 'Acknowledged $done alert(s)');
    } catch (e) {
      AppErrorLogger.log('AlertBloc.bulkAcknowledge', e);
      emit(AlertError('Bulk acknowledge failed after $done alert(s)'));
    }
  }

  Future<void> _onResolved(
    AlertResolved event,
    Emitter<AlertState> emit,
  ) async {
    try {
      await _repo.resolveAlert(event.nodeId, event.alertId);
      await _audit?.log(
        userId: event.userId,
        userName: event.userName,
        action: AuditActions.alertResolved,
        details: 'Resolved alert ${event.alertId} on node ${event.nodeId}',
      );
      _succeed(emit, 'Alert resolved');
    } catch (e) {
      AppErrorLogger.log('AlertBloc.resolve', e);
      emit(AlertError('Failed to resolve: ${e.toString()}'));
    }
  }

  Future<void> _onDismissed(
    AlertDismissed event,
    Emitter<AlertState> emit,
  ) async {
    try {
      await _repo.dismissAlert(
        event.nodeId,
        event.alertId,
        event.userId,
        event.reason,
      );
      await _audit?.log(
        userId: event.userId,
        userName: event.userName,
        action: AuditActions.alertDismissed,
        details:
            'Dismissed alert ${event.alertId} on ${event.nodeId}: ${event.reason}',
      );
      _succeed(emit, 'Alert dismissed');
    } catch (e) {
      AppErrorLogger.log('AlertBloc.dismiss', e);
      emit(AlertError('Failed to dismiss: ${e.toString()}'));
    }
  }

  void _succeed(Emitter<AlertState> emit, String message) {
    final current = state;
    if (current is AlertLoaded) {
      emit(AlertActionSuccess(
        alerts: current.alerts,
        message: message,
        statusFilter: current.statusFilter,
        severityFilter: current.severityFilter,
        nodeFilter: current.nodeFilter,
        query: current.query,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}

Future<void> _onStreamError(
  AlertStreamError event,
  Emitter<AlertState> emit,
) async {
  AppErrorLogger.log('AlertBloc.streamMessage', event.message);
  emit(AlertError(event.message));
}
