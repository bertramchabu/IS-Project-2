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

  const PredictionLoaded(this.prediction);

  @override
  List<Object?> get props => [prediction];
}

class PredictionError extends PredictionState {
  final String message;

  const PredictionError(this.message);

  @override
  List<Object?> get props => [message];
}
