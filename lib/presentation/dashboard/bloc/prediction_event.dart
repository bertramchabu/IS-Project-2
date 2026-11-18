import 'package:equatable/equatable.dart';
import '../../../data/models/kpi_metric_model.dart';
import '../../../data/models/prediction_model.dart';

abstract class PredictionEvent extends Equatable {
  const PredictionEvent();

  @override
  List<Object?> get props => [];
}

class PredictionStarted extends PredictionEvent {
  final String nodeId;

  const PredictionStarted(this.nodeId);

  @override
  List<Object?> get props => [nodeId];
}

class PredictionMetricsReceived extends PredictionEvent {
  final String nodeId;
  final List<KpiMetricModel> metrics;
  final bool isReplay;

  const PredictionMetricsReceived({
    required this.nodeId,
    required this.metrics,
    this.isReplay = false,
  });

  @override
  List<Object?> get props => [nodeId, metrics, isReplay];
}

class PredictionFirestoreUpdated extends PredictionEvent {
  final String nodeId;
  final PredictionModel? prediction;

  const PredictionFirestoreUpdated({
    required this.nodeId,
    required this.prediction,
  });

  @override
  List<Object?> get props => [nodeId, prediction];
}

class PredictionApiStatusChanged extends PredictionEvent {
  final String nodeId;
  final bool isOnline;
  final bool isModelLoaded;
  final String modelVersion;
  final double? f1Score;
  final double? rmse;
  final String message;

  const PredictionApiStatusChanged({
    required this.nodeId,
    required this.isOnline,
    required this.isModelLoaded,
    required this.modelVersion,
    required this.f1Score,
    required this.rmse,
    required this.message,
  });

  @override
  List<Object?> get props =>
      [nodeId, isOnline, isModelLoaded, modelVersion, f1Score, rmse, message];
}

class PredictionStreamFailed extends PredictionEvent {
  final String nodeId;
  final String message;

  const PredictionStreamFailed({
    required this.nodeId,
    required this.message,
  });

  @override
  List<Object?> get props => [nodeId, message];
}
