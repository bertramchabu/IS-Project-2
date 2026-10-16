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
    on<_AlertsReceived>(_onReceived);
  }

  Future<void> _onStarted(
    AlertsStarted event,
    Emitter<AlertState> emit,
  ) async {
    emit(const AlertLoading());
    await _sub?.cancel();
    _sub = _repo
        .watchAlerts(statusFilter: _currentFilter)
        .listen(
          (alerts) => add(_AlertsReceived(alerts)),
          onError: (e) => emit(AlertError(e.toString())),
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
    _AlertsReceived event,
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
      await _repo.acknowledgeAlert(event.alertId, event.userId);
      final current = state;
      if (current is AlertLoaded) {
        emit(AlertActionSuccess(
          alerts: current.alerts,
          message: 'Alert acknowledged',
          statusFilter: current.statusFilter,
        ));
      }
    } catch (e) {
      emit(AlertError('Failed to acknowledge: ${e.toString()}'));
    }
  }

  Future<void> _onDismissed(
    AlertDismissed event,
    Emitter<AlertState> emit,
  ) async {
    try {
      await _repo.dismissAlert(
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
      emit(AlertError('Failed to dismiss: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}