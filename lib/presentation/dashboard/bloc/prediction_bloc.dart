import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/prediction_repository.dart';
import 'prediction_event.dart';
import 'prediction_state.dart';

class PredictionBloc extends Bloc<PredictionEvent, PredictionState> {
  final PredictionRepository _repo;

  StreamSubscription? _sub;

  PredictionBloc(this._repo) : super(const PredictionInitial()) {
    on<PredictionStarted>(_onStarted);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('[PredictionBloc] Unhandled error: $error');
    super.onError(error, stackTrace);
  }

  Future<void> _onStarted(
    PredictionStarted event,
    Emitter<PredictionState> emit,
  ) async {
    emit(const PredictionLoading());
    await _sub?.cancel();
    _sub = _repo.watchLatestPrediction(event.nodeId).listen(
      (prediction) => emit(PredictionLoaded(prediction)),
      onError: (e) {
        print('[PredictionBloc] Prediction stream error: $e');
        emit(PredictionError(e.toString()));
      },
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
