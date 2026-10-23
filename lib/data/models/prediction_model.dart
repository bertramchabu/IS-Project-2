import 'package:cloud_firestore/cloud_firestore.dart';
import 'alert_model.dart' show AlertSeverity;

class PredictionModel {
  final String predictionId;
  final String nodeId;
  final String modelVersionId;
  final double faultProbability;
  final AlertSeverity severity;
  final List<double> inputFeatures;
  final int? inferenceTimeMs;
  final bool adaptiveReductionApplied;
  final DateTime predictionTimestamp;
  final DateTime? inputTimestamp;
  final String triggeredBy;
  final String? operationalStatus;
  final String? message;
  final int? computationalSavingsPercent;
  final double? nextSamplingIntervalSeconds;
  final double? modelF1Score;
  final double? modelRmse;

  const PredictionModel({
    required this.predictionId,
    required this.nodeId,
    required this.modelVersionId,
    required this.faultProbability,
    required this.severity,
    required this.inputFeatures,
    this.inferenceTimeMs,
    required this.adaptiveReductionApplied,
    required this.predictionTimestamp,
    this.inputTimestamp,
    required this.triggeredBy,
    this.operationalStatus,
    this.message,
    this.computationalSavingsPercent,
    this.nextSamplingIntervalSeconds,
    this.modelF1Score,
    this.modelRmse,
  });

  factory PredictionModel.fromFirestore(
    DocumentSnapshot doc,
    String nodeId,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    final prob = (d['faultProbability'] as num?)?.toDouble() ?? 0.0;
    return PredictionModel(
      predictionId: doc.id,
      nodeId: nodeId,
      modelVersionId: d['modelVersionId'] as String? ?? 'v1.2.0',
      faultProbability: prob,
      severity: _severityFromProbability(prob),
      inputFeatures: (d['inputFeatures'] as List<dynamic>?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          const [],
      inferenceTimeMs: (d['inferenceTimeMs'] as num?)?.toInt() ?? 12,
      adaptiveReductionApplied: d['adaptiveReductionApplied'] as bool? ?? false,
      predictionTimestamp:
          (d['predictionTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inputTimestamp: (d['inputTimestamp'] as Timestamp?)?.toDate(),
      triggeredBy: d['triggeredBy'] as String? ?? 'BiLSTM Inference',
      operationalStatus: d['status'] as String?,
      message: d['message'] as String?,
      computationalSavingsPercent:
          (d['computationalSavingsPercent'] as num?)?.toInt(),
      nextSamplingIntervalSeconds:
          (d['nextSamplingIntervalSeconds'] as num?)?.toDouble(),
      modelF1Score: (d['modelF1Score'] as num?)?.toDouble(),
      modelRmse: (d['modelRmse'] as num?)?.toDouble(),
    );
  }

  static AlertSeverity _severityFromProbability(double p) {
    if (p >= 0.80) return AlertSeverity.critical;
    if (p >= 0.60) return AlertSeverity.high;
    if (p >= 0.40) return AlertSeverity.medium;
    return AlertSeverity.low;
  }

  bool get exceedsThreshold => faultProbability >= 0.70;
  bool get isHigh => faultProbability >= 0.60;
  bool get isCritical => faultProbability >= 0.80;

  String get probabilityPercent =>
      '${(faultProbability * 100).toStringAsFixed(1)}%';

  String get severityLabel {
    switch (severity) {
      case AlertSeverity.low:
        return 'LOW';
      case AlertSeverity.medium:
        return 'MEDIUM';
      case AlertSeverity.high:
        return 'HIGH';
      case AlertSeverity.critical:
        return 'CRITICAL';
    }
  }
}
