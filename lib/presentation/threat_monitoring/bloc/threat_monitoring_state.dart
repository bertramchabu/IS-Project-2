import 'package:equatable/equatable.dart';

import '../../../data/models/threat_feed_item.dart';
import '../../../data/repositories/threat_repository.dart';
import '../../../services/threat_features/threat_feature_window.dart';

enum ThreatMonitoringStatus { initial, loading, loaded, failure }

class ThreatMonitoringState extends Equatable {
  final ThreatMonitoringStatus status;
  final List<ThreatFeedItem> assessments;
  final List<ThreatFeedItem> demoAssessments;
  final bool demoRunning;
  final ThreatLabel? categoryFilter;
  final String? errorMessage;
  final List<ThreatEvidenceRecord> exportedEvidence;

  const ThreatMonitoringState({
    this.status = ThreatMonitoringStatus.initial,
    this.assessments = const [],
    this.demoAssessments = const [],
    this.demoRunning = false,
    this.categoryFilter,
    this.errorMessage,
    this.exportedEvidence = const [],
  });

  List<ThreatFeedItem> get filteredAssessments => categoryFilter == null
      ? assessments
      : assessments
          .where(
              (assessment) => assessment.category == categoryFilter!.wireValue)
          .toList();

  List<ThreatFeedItem> get filteredDemoAssessments => categoryFilter == null
      ? demoAssessments
      : demoAssessments
          .where(
              (assessment) => assessment.category == categoryFilter!.wireValue)
          .toList();

  List<ThreatFeedItem> get visibleAssessments => [
        ...filteredDemoAssessments,
        ...filteredAssessments,
      ];

  ThreatMonitoringState copyWith({
    ThreatMonitoringStatus? status,
    List<ThreatFeedItem>? assessments,
    List<ThreatFeedItem>? demoAssessments,
    bool? demoRunning,
    ThreatLabel? categoryFilter,
    bool clearCategoryFilter = false,
    String? errorMessage,
    bool clearError = false,
    List<ThreatEvidenceRecord>? exportedEvidence,
  }) {
    return ThreatMonitoringState(
      status: status ?? this.status,
      assessments: assessments ?? this.assessments,
      demoAssessments: demoAssessments ?? this.demoAssessments,
      demoRunning: demoRunning ?? this.demoRunning,
      categoryFilter:
          clearCategoryFilter ? null : categoryFilter ?? this.categoryFilter,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      exportedEvidence: exportedEvidence ?? this.exportedEvidence,
    );
  }

  @override
  List<Object?> get props => [
        status,
        assessments,
        demoAssessments,
        demoRunning,
        categoryFilter,
        errorMessage,
        exportedEvidence,
      ];
}
