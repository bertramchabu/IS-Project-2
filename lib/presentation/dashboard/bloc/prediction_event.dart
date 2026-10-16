import 'package:equatable/equatable.dart';

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
