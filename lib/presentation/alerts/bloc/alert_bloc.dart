import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';
import 'alert_event.dart';
import 'alert_state.dart';

class AlertBloc extends Bloc<AlertEvent, AlertState> {
  final AlertRepository _repo;

  StreamSubscription? _sub;
  AlertStatus? _currentFilter;

  AlertBloc(this._repo) : super(const AlertInitial()) {
    on<AlertsStarted>(_onStarted);
    on<AlertStatusFilterChanged>(_onFilterChanged);
    on<AlertAcknowledged>(_onAcknowledged);
    on<AlertDismissed>(_onDismissed);
    on<AlertsReceived>(_onReceived);
    on<AlertStreamError>(_onStreamError);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('[AlertBloc] Unhandled error: $error');
    super.onError(error, stackTrace);
  }

  Future<void> _onStarted(
    AlertsStarted event,
    Emitter<AlertState> emit,
  ) async {
    _sub = _repo.watchAlerts(statusFilter: _currentFilter).listen(
          (alerts) => add(AlertsReceived(alerts)),
          onError: (e) => add(AlertStreamError(e.toString())),
        );
  }

  Future<void> _onFilterChanged(
    AlertStatusFilterChanged event,
    Emitter<AlertState> emit,
  ) async {
    _currentFilter = event.filter;
    add(const AlertsStarted());
  }

  Future<void> _onReceived(
    AlertsReceived event,
    Emitter<AlertState> emit,
  ) async {
    emit(AlertLoaded(
      alerts: event.alerts,
      statusFilter: _currentFilter,
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
      final current = state;
      if (current is AlertLoaded) {
        emit(AlertActionSuccess(
          alerts: current.alerts,
          message: 'Alert acknowledged',
          statusFilter: current.statusFilter,
        ));
      }
    } catch (e) {
      print('[AlertBloc] Failed to acknowledge alert: $e');
      emit(AlertError('Failed to acknowledge: ${e.toString()}'));
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
      final current = state;
      if (current is AlertLoaded) {
        emit(AlertActionSuccess(
          alerts: current.alerts,
          message: 'Alert dismissed',
          statusFilter: current.statusFilter,
        ));
      }
    } catch (e) {
      print('[AlertBloc] Failed to dismiss alert: $e');
      emit(AlertError('Failed to dismiss: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

Future<void> _onStreamError(
  AlertStreamError event,
  Emitter<AlertState> emit,
) async {
  print('[AlertBloc] Alert stream error: ${event.message}');
  emit(AlertError(event.message));
}
