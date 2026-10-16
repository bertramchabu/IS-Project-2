import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

class ModelInferenceRepository {
  final http.Client _client;
  final Uri _baseUri;
  String _modelVersion = 'unknown';
  double? _f1Score;
  double? _rmse;

  ModelInferenceRepository({
    http.Client? client,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _baseUri = baseUri ?? _defaultBaseUri();

  static Uri _defaultBaseUri() {
    const configuredUrl = String.fromEnvironment('MODEL_API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      return Uri.parse(configuredUrl);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse('http://10.0.2.2:8000');
    }
    return Uri.parse('http://127.0.0.1:8000');
  }

  Future<ModelApiStatus> checkStatus() async {
    final response = await _client
        .get(_baseUri.resolve('/health'))
        .timeout(const Duration(seconds: 4));
    final health = _decodeObject(response);
    final isOnline = health['status'] == 'online';
    final isModelLoaded =
        health['model_loaded'] == true && health['scaler_loaded'] == true;

    if (isModelLoaded) {
      final metadataResponse = await _client
          .get(_baseUri.resolve('/model/metadata'))
          .timeout(const Duration(seconds: 4));
      final metadata = _decodeObject(metadataResponse);
      _modelVersion =
          metadata['version_number'] as String? ?? _modelVersion;
      _f1Score = _optionalDouble(metadata['f1_score']);
      _rmse = _optionalDouble(metadata['rmse']);
    }

    return ModelApiStatus(
      isOnline: isOnline,
      isModelLoaded: isModelLoaded,
      modelVersion: _modelVersion,
      f1Score: _f1Score,
      rmse: _rmse,
      message: isModelLoaded
          ? 'Model ${_modelVersion} is ready'
          : 'Inference API is reachable, but model artifacts are not loaded',
    );
  }

  Future<PredictionModel> predictLiveMetric({
    required String nodeId,
    required List<KpiMetricModel> metrics,
  }) async {
    final latestByType = <MetricType, KpiMetricModel>{};
    for (final metric in metrics) {
      final current = latestByType[metric.metricType];
      if (current == null || metric.timestamp.isAfter(current.timestamp)) {
        latestByType[metric.metricType] = metric;
      }
    }

    if (MetricType.values.any((type) => !latestByType.containsKey(type))) {
      throw StateError('Waiting for all five KPI types before inference.');
    }

    final samples = MetricType.values.map((type) => latestByType[type]!).toList();
    final timestamps = samples.map((sample) => sample.timestamp).toList();
    timestamps.sort();
    if (timestamps.last.difference(timestamps.first) >
        const Duration(seconds: 5)) {
      throw StateError('Latest KPI values are not from the same time window.');
    }

    final response = await _client
        .post(
          _baseUri.resolve('/predict/live-metric'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'node_id': nodeId,
            'timestamp': timestamps.last.toUtc().toIso8601String(),
            'kpis': {
              for (var index = 0; index < MetricType.values.length; index++)
                _apiMetricName(MetricType.values[index]):
                    samples[index].value,
            },
          }),
        )
        .timeout(const Duration(seconds: 4));
    final result = _decodeObject(response);

    final probability = _requiredDouble(result, 'fault_probability');
    if (probability < 0 || probability > 1) {
      throw const FormatException(
        'Model API returned a fault probability outside 0..1.',
      );
    }

    final timestampValue = result['timestamp'];
    final predictionTimestamp = timestampValue is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (timestampValue * 1000).round(),
            isUtc: true,
          )
        : DateTime.now().toUtc();

    return PredictionModel(
      predictionId: '$nodeId-${predictionTimestamp.microsecondsSinceEpoch}',
      nodeId: nodeId,
      modelVersionId: _modelVersion,
      faultProbability: probability,
      severity: _severityFromApi(result['severity'] as String?),
      inputFeatures: samples.map((sample) => sample.value).toList(),
      inferenceTimeMs: _optionalDouble(result['inference_latency_ms'])?.round(),
      adaptiveReductionApplied:
          (_optionalDouble(result['computational_savings_percent']) ?? 0) > 0,
      predictionTimestamp: predictionTimestamp,
      triggeredBy: 'Live BiLSTM API',
      operationalStatus: result['status'] as String?,
      message: result['message'] as String?,
      computationalSavingsPercent:
          _optionalDouble(result['computational_savings_percent'])?.round(),
      nextSamplingIntervalSeconds:
          _optionalDouble(result['next_sampling_interval_sec']),
      modelF1Score: _f1Score,
      modelRmse: _rmse,
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Model API returned HTTP ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Model API response must be a JSON object.');
    }
    return decoded;
  }

  double _requiredDouble(Map<String, dynamic> response, String key) {
    final value = _optionalDouble(response[key]);
    if (value == null || !value.isFinite) {
      throw FormatException('Model API response is missing numeric "$key".');
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
        return AlertSeverity.critical;
      case 'HIGH':
        return AlertSeverity.high;
      case 'MEDIUM':
      case 'WARNING':
        return AlertSeverity.medium;
      default:
        return AlertSeverity.low;
    }
  }
}
