import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/prediction_repository.dart';
import '../../../data/repositories/model_inference_repository.dart';
import 'prediction_event.dart';
import 'prediction_state.dart';

class PredictionBloc extends Bloc<PredictionEvent, PredictionState> {
  final PredictionRepository _repo;
  final ModelInferenceRepository _modelRepo;

  StreamSubscription? _firestoreSub;
  String? _activeNodeId;
  String? _lastSampleKey;
  DateTime? _nextInferenceAllowedAt;

  PredictionBloc(this._repo, this._modelRepo)
      : super(const PredictionInitial()) {
    on<PredictionStarted>(_onStarted);
    on<PredictionMetricsReceived>(_onMetricsReceived);
    on<PredictionFirestoreUpdated>(_onFirestoreUpdated);
    on<PredictionApiStatusChanged>(_onApiStatusChanged);
    on<PredictionStreamFailed>(_onStreamFailed);
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
    _activeNodeId = event.nodeId;
    _lastSampleKey = null;
    _nextInferenceAllowedAt = null;
    await _firestoreSub?.cancel();
    emit(const PredictionLoading());
    _firestoreSub = _repo.watchLatestPrediction(event.nodeId).listen(
      (prediction) => add(PredictionFirestoreUpdated(
        nodeId: event.nodeId,
        prediction: prediction,
      )),
      onError: (e) {
        print('[PredictionBloc] Prediction stream error: $e');
        add(PredictionStreamFailed(
          nodeId: event.nodeId,
          message: e.toString(),
        ));
      },
    );

    try {
      final status = await _modelRepo.checkStatus();
      if (_activeNodeId == event.nodeId) {
        add(PredictionApiStatusChanged(
          nodeId: event.nodeId,
          isOnline: status.isOnline,
          isModelLoaded: status.isModelLoaded,
          modelVersion: status.modelVersion,
          f1Score: status.f1Score,
          rmse: status.rmse,
          message: status.message,
        ));
      }
    } catch (error) {
      print('[PredictionBloc] Model API health check failed: $error');
      if (_activeNodeId == event.nodeId) {
        add(PredictionApiStatusChanged(
          nodeId: event.nodeId,
          isOnline: false,
          isModelLoaded: false,
          modelVersion: 'unknown',
          f1Score: null,
          rmse: null,
          message: 'Model API is unavailable: $error',
        ));
      }
    }
  }

  Future<void> _onMetricsReceived(
    PredictionMetricsReceived event,
    Emitter<PredictionState> emit,
  ) async {
    if (event.nodeId != _activeNodeId) return;

    final window = _modelRepo.latestWindow(event.metrics);
    if (window == null ||
        DateTime.now().difference(window.timestamp) >
            const Duration(seconds: 10)) {
      return;
    }
    if (window.sampleKey == _lastSampleKey) return;
    _lastSampleKey = window.sampleKey;
    if (_nextInferenceAllowedAt != null &&
        DateTime.now().isBefore(_nextInferenceAllowedAt!)) {
      return;
    }

    if (!window.isReady) {
      final current = state;
      emit(PredictionLoaded(
        current is PredictionLoaded ? current.prediction : null,
        modelApiOnline: current is PredictionLoaded && current.modelApiOnline,
        modelLoaded: current is PredictionLoaded && current.modelLoaded,
        modelVersion:
            current is PredictionLoaded ? current.modelVersion : 'unknown',
        modelF1Score: current is PredictionLoaded ? current.modelF1Score : null,
        modelRmse: current is PredictionLoaded ? current.modelRmse : null,
        statusMessage:
            'Buffering KPI sequence (${window.sampleCount}/${ModelInferenceRepository.windowSize} samples).',
        predictionSource: current is PredictionLoaded
            ? current.predictionSource
            : 'Firestore',
      ));
      return;
    }

    try {
      final prediction = await _modelRepo.predictLiveMetric(
        nodeId: event.nodeId,
        window: window,
      );
      if (_activeNodeId != event.nodeId) return;
      final nextInterval = prediction.nextSamplingIntervalSeconds ?? 1.0;
      _nextInferenceAllowedAt = DateTime.now().add(
        Duration(milliseconds: (nextInterval * 1000).round()),
      );
      emit(PredictionLoaded(
        prediction,
        modelApiOnline: true,
        modelLoaded: true,
        modelVersion: prediction.modelVersionId,
        modelF1Score: prediction.modelF1Score,
        modelRmse: prediction.modelRmse,
        statusMessage: prediction.message,
        predictionSource: 'Live BiLSTM API',
      ));
    } catch (error) {
      if (error is ModelSequenceNotReadyException) {
        final current = state;
        emit(PredictionLoaded(
          current is PredictionLoaded ? current.prediction : null,
          modelApiOnline: current is PredictionLoaded && current.modelApiOnline,
          modelLoaded: current is PredictionLoaded && current.modelLoaded,
          modelVersion:
              current is PredictionLoaded ? current.modelVersion : 'unknown',
          modelF1Score:
              current is PredictionLoaded ? current.modelF1Score : null,
          modelRmse: current is PredictionLoaded ? current.modelRmse : null,
          statusMessage: error.message,
          predictionSource: current is PredictionLoaded
              ? current.predictionSource
              : 'Firestore',
        ));
        return;
      }
      print('[PredictionBloc] Live model inference failed: $error');
      if (_activeNodeId != event.nodeId) return;
      final current = state;
      emit(PredictionLoaded(
        current is PredictionLoaded ? current.prediction : null,
        modelApiOnline: false,
        modelLoaded: false,
        modelVersion:
            current is PredictionLoaded ? current.modelVersion : 'unknown',
        modelF1Score: current is PredictionLoaded ? current.modelF1Score : null,
        modelRmse: current is PredictionLoaded ? current.modelRmse : null,
        statusMessage: 'Live inference failed: $error',
        predictionSource: current is PredictionLoaded
            ? current.predictionSource
            : 'Firestore',
      ));
    }
  }

  Future<void> _onFirestoreUpdated(
    PredictionFirestoreUpdated event,
    Emitter<PredictionState> emit,
  ) async {
    if (event.nodeId != _activeNodeId) return;
    final current = state;
    if (current is PredictionLoaded &&
        current.predictionSource == 'Live BiLSTM API') {
      return;
    }
    emit(PredictionLoaded(
      event.prediction,
      modelApiOnline: current is PredictionLoaded && current.modelApiOnline,
      modelLoaded: current is PredictionLoaded && current.modelLoaded,
      modelVersion: current is PredictionLoaded
          ? current.modelVersion
          : event.prediction?.modelVersionId ?? 'unknown',
      modelF1Score: current is PredictionLoaded
          ? current.modelF1Score
          : event.prediction?.modelF1Score,
      modelRmse: current is PredictionLoaded
          ? current.modelRmse
          : event.prediction?.modelRmse,
      statusMessage: current is PredictionLoaded ? current.statusMessage : null,
      predictionSource: 'Firestore',
    ));
  }

  Future<void> _onApiStatusChanged(
    PredictionApiStatusChanged event,
    Emitter<PredictionState> emit,
  ) async {
    if (event.nodeId != _activeNodeId) return;
    final current = state;
    emit(PredictionLoaded(
      current is PredictionLoaded ? current.prediction : null,
      modelApiOnline: event.isOnline,
      modelLoaded: event.isModelLoaded,
      modelVersion: event.modelVersion,
      modelF1Score: event.f1Score,
      modelRmse: event.rmse,
      statusMessage: event.message,
      predictionSource:
          current is PredictionLoaded ? current.predictionSource : 'Firestore',
    ));
  }

  Future<void> _onStreamFailed(
    PredictionStreamFailed event,
    Emitter<PredictionState> emit,
  ) async {
    if (event.nodeId != _activeNodeId) return;
    final current = state;
    emit(PredictionLoaded(
      current is PredictionLoaded ? current.prediction : null,
      modelApiOnline: current is PredictionLoaded && current.modelApiOnline,
      modelLoaded: current is PredictionLoaded && current.modelLoaded,
      modelVersion:
          current is PredictionLoaded ? current.modelVersion : 'unknown',
      modelF1Score: current is PredictionLoaded ? current.modelF1Score : null,
      modelRmse: current is PredictionLoaded ? current.modelRmse : null,
      statusMessage: 'Prediction stream error: ${event.message}',
      predictionSource:
          current is PredictionLoaded ? current.predictionSource : 'Firestore',
    ));
  }

  @override
  Future<void> close() async {
    await _firestoreSub?.cancel();
    await super.close();
  }
}
