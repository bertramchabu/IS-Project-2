import 'package:equatable/equatable.dart';

import '../../../data/models/threat_feed_item.dart';
import '../../../services/threat_features/threat_feature_window.dart';

abstract class ThreatMonitoringEvent extends Equatable {
  const ThreatMonitoringEvent();

  @override
  List<Object?> get props => [];
}

class ThreatMonitoringStarted extends ThreatMonitoringEvent {
  const ThreatMonitoringStarted();
}

class ThreatDemoReplayRequested extends ThreatMonitoringEvent {
  const ThreatDemoReplayRequested();
}

class ThreatCategoryFilterChanged extends ThreatMonitoringEvent {
  final ThreatLabel? category;

  const ThreatCategoryFilterChanged(this.category);

  @override
  List<Object?> get props => [category];
}

class ThreatLifecycleRequested extends ThreatMonitoringEvent {
  final ThreatFeedItem assessment;
  final String eventType;
  final String details;
  final String? nextStatus;

  const ThreatLifecycleRequested({
    required this.assessment,
    required this.eventType,
    required this.details,
    this.nextStatus,
  });

  @override
  List<Object?> get props => [assessment, eventType, details, nextStatus];
}

class ThreatEvidenceExportRequested extends ThreatMonitoringEvent {
  final String assessmentId;

  const ThreatEvidenceExportRequested(this.assessmentId);

  @override
  List<Object?> get props => [assessmentId];
}

class ThreatAssessmentsReceived extends ThreatMonitoringEvent {
  final List<ThreatFeedItem> assessments;

  const ThreatAssessmentsReceived(this.assessments);

  @override
  List<Object?> get props => [assessments];
}

class ThreatAssessmentsFailed extends ThreatMonitoringEvent {
  final String message;

  const ThreatAssessmentsFailed(this.message);

  @override
  List<Object?> get props => [message];
}
