import 'package:equatable/equatable.dart';
import '../../../data/models/prediction_model.dart';

abstract class PredictionState extends Equatable {
  const PredictionState();

  @override
  List<Object?> get props => [];
}

class PredictionInitial extends PredictionState {
  const PredictionInitial();
}

class PredictionLoading extends PredictionState {
  const PredictionLoading();
}

class PredictionLoaded extends PredictionState {
  final PredictionModel? prediction;
  final bool modelApiOnline;
  final bool modelLoaded;
  final String modelVersion;
  final double? modelF1Score;
  final double? modelRmse;
  final String? statusMessage;
  final String predictionSource;

  const PredictionLoaded(
    this.prediction, {
    this.modelApiOnline = false,
    this.modelLoaded = false,
    this.modelVersion = 'unknown',
    this.modelF1Score,
    this.modelRmse,
    this.statusMessage,
    this.predictionSource = 'Firestore',
  });

  @override
  List<Object?> get props => [
        prediction,
        modelApiOnline,
        modelLoaded,
        modelVersion,
        modelF1Score,
        modelRmse,
        statusMessage,
        predictionSource,
      ];
}

class PredictionError extends PredictionState {
  final String message;

  const PredictionError(this.message);

  @override
  List<Object?> get props => [message];
}
