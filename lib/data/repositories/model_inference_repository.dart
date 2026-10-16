import 'package:cloud_functions/cloud_functions.dart';

import '../models/alert_model.dart';
import '../models/kpi_metric_model.dart';
import '../models/prediction_model.dart';

class ModelApiStatus {
  final bool isOnline;
  final bool isModelLoaded;
  final String modelVersion;
  final double? f1Score;
  final double? rmse;
  final String message;

  const ModelApiStatus({
    required this.isOnline,
    required this.isModelLoaded,
    required this.modelVersion,
    required this.f1Score,
    required this.rmse,
    required this.message,
  });
}

class ModelSequenceNotReadyException implements Exception {
  final String message;

  const ModelSequenceNotReadyException(this.message);

  @override
  String toString() => message;
}

class ModelInferenceRepository {
  static const _windowSize = 10;
  static const _sampleGroupingWindow = Duration(milliseconds: 750);

  final FirebaseFunctions _functions;
  String _modelVersion = 'unknown';
  double? _f1Score;
  double? _rmse;

  ModelInferenceRepository({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<ModelApiStatus> checkStatus() async {
    final result = await _functions.httpsCallable('model_status').call();
    final status = _asMap(result.data);
    final isOnline = status['online'] == true;
    final isModelLoaded = status['model_loaded'] == true;
    _modelVersion = status['model_version'] as String? ?? 'unknown';
    _f1Score = _optionalDouble(status['f1_score']);
    _rmse = _optionalDouble(status['rmse']);

    return ModelApiStatus(
      isOnline: isOnline,
      isModelLoaded: isModelLoaded,
      modelVersion: _modelVersion,
      f1Score: _f1Score,
      rmse: _rmse,
      message: isModelLoaded
          ? 'Model $_modelVersion is ready'
          : 'Model function is reachable, but the model is not loaded',
    );
  }

  Future<PredictionModel> predictLiveMetric({
    required String nodeId,
    required List<KpiMetricModel> metrics,
  }) async {
    final sequence = _buildSequence(metrics);
    final result = await _functions.httpsCallable('predict_fault').call({
      'node_id': nodeId,
      'sequence': sequence,
    });
    final prediction = _asMap(result.data);
    final probability = _requiredDouble(prediction, 'fault_probability');
    if (probability < 0 || probability > 1) {
      throw const FormatException(
        'Model function returned a fault probability outside 0..1.',
      );
    }

    final timestampValue = prediction['timestamp'];
    final predictionTimestamp = timestampValue is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (timestampValue * 1000).round(),
            isUtc: true,
          )
        : DateTime.now().toUtc();
    _modelVersion =
        prediction['model_version'] as String? ?? _modelVersion;

    return PredictionModel(
      predictionId: '$nodeId-${predictionTimestamp.microsecondsSinceEpoch}',
      nodeId: nodeId,
      modelVersionId: _modelVersion,
      faultProbability: probability,
      severity: _severityFromApi(prediction['severity'] as String?),
      inputFeatures: sequence.last.values.toList(),
      inferenceTimeMs: _optionalDouble(prediction['inference_latency_ms'])?.round(),
      adaptiveReductionApplied: false,
      predictionTimestamp: predictionTimestamp,
      triggeredBy: 'Firebase BiLSTM Function',
      operationalStatus: prediction['status'] as String?,
      message: prediction['message'] as String?,
      computationalSavingsPercent:
          _optionalDouble(prediction['computational_savings_percent'])?.round(),
      nextSamplingIntervalSeconds:
          _optionalDouble(prediction['next_sampling_interval_sec']),
      modelF1Score: _f1Score,
      modelRmse: _rmse,
    );
  }

  List<Map<String, double>> _buildSequence(List<KpiMetricModel> metrics) {
    final sorted = metrics.toList()
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final samples = <List<KpiMetricModel>>[];
    var group = <KpiMetricModel>[];
    DateTime? groupStart;

    void finishGroup() {
      if (group.isNotEmpty) samples.add(group);
      group = [];
      groupStart = null;
    }

    for (final metric in sorted) {
      if (groupStart != null &&
          metric.timestamp.difference(groupStart!) > _sampleGroupingWindow) {
        finishGroup();
      }
      groupStart ??= metric.timestamp;
      group.add(metric);
    }
    finishGroup();

    final alignedSamples = <Map<MetricType, KpiMetricModel>>[];
    for (final sampleGroup in samples) {
      final latestByType = <MetricType, KpiMetricModel>{};
      for (final metric in sampleGroup) {
        final current = latestByType[metric.metricType];
        if (current == null || metric.timestamp.isAfter(current.timestamp)) {
          latestByType[metric.metricType] = metric;
        }
      }
      if (MetricType.values.every(latestByType.containsKey)) {
        alignedSamples.add(latestByType);
      }
    }

    if (alignedSamples.length < _windowSize) {
      throw ModelSequenceNotReadyException(
        'Buffering KPI sequence (${alignedSamples.length}/$_windowSize samples).',
      );
    }

    final recentSamples = alignedSamples.skip(alignedSamples.length - _windowSize);
    return recentSamples.map((sample) {
      return {
        for (final type in MetricType.values)
          _apiMetricName(type): sample[type]!.value,
      };
    }).toList();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Model function response must be a JSON object.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  double _requiredDouble(Map<String, dynamic> response, String key) {
    final value = _optionalDouble(response[key]);
    if (value == null || !value.isFinite) {
      throw FormatException('Model response is missing numeric "$key".');
    }
    return value;
  }

  double? _optionalDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  String _apiMetricName(MetricType type) {
    switch (type) {
      case MetricType.latency:
        return 'latency';
      case MetricType.jitter:
        return 'jitter';
      case MetricType.packetLoss:
        return 'packet_loss';
      case MetricType.retransmissionRate:
        return 'retransmission_rate';
      case MetricType.signalStrength:
        return 'signal_strength';
    }
  }

  AlertSeverity _severityFromApi(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return AlertSeverity.critical;
      case 'MEDIUM':
      case 'WARNING':
        return AlertSeverity.medium;
      default:
        return AlertSeverity.low;
    }
  }
}
