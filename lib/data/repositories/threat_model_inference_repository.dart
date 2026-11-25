import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/threat_detection/threat_classifier.dart';
import '../../services/threat_features/threat_feature_window.dart';

class ThreatModelApiStatus {
  final bool isOnline;
  final bool isModelLoaded;
  final String modelVersion;
  final String datasetVersion;
  final String classifier;
  final int forecastHorizonMinutes;
  final int inputFeatureCount;

  const ThreatModelApiStatus({
    required this.isOnline,
    required this.isModelLoaded,
    required this.modelVersion,
    required this.datasetVersion,
    required this.classifier,
    required this.forecastHorizonMinutes,
    required this.inputFeatureCount,
  });
}

class ThreatModelInferenceRepository {
  final FirebaseAuth _auth;
  final FirebaseFunctions? _configuredFunctions;

  FirebaseFunctions? _functions;

  ThreatModelInferenceRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _configuredFunctions = functions;

  FirebaseFunctions get _callables => _functions ??= _configuredFunctions ??
      FirebaseFunctions.instanceFor(
        app: _auth.app,
        region: 'us-central1',
      );

  Future<ThreatModelApiStatus> checkStatus() async {
    if (_auth.currentUser == null) {
      throw StateError('Sign in before checking cloud threat-model status.');
    }

    final response =
        await _callables.httpsCallable('threat_model_status').call();
    final result = _asMap(response.data);
    final online = result['online'];
    final modelLoaded = result['model_loaded'];
    final modelVersion = result['model_version'];
    final datasetVersion = result['dataset_version'];
    final classifier = result['classifier'];
    final forecastHorizon = result['forecast_horizon_minutes'];
    final inputFeatures = result['input_features'];
    if (online is! bool ||
        modelLoaded is! bool ||
        result['simulation_only'] != true ||
        result['supports_demo_only'] != true ||
        modelVersion is! String ||
        modelVersion.trim().isEmpty ||
        datasetVersion is! String ||
        datasetVersion.trim().isEmpty ||
        classifier is! String ||
        classifier.trim().isEmpty ||
        forecastHorizon is! num ||
        !forecastHorizon.isFinite ||
        forecastHorizon < 1 ||
        inputFeatures is! List ||
        inputFeatures.isEmpty ||
        inputFeatures.any((feature) => feature is! String)) {
      throw const FormatException(
        'Threat model status response is incomplete or not simulation-only.',
      );
    }

    return ThreatModelApiStatus(
      isOnline: online,
      isModelLoaded: modelLoaded,
      modelVersion: modelVersion,
      datasetVersion: datasetVersion,
      classifier: classifier,
      forecastHorizonMinutes: forecastHorizon.toInt(),
      inputFeatureCount: inputFeatures.length,
    );
  }

  Future<ThreatClassifierResult> classifySyntheticWindow(
    ThreatFeatureWindow window,
  ) async {
    if (_auth.currentUser == null) {
      throw StateError('Sign in before running the cloud threat-model demo.');
    }
    if (!window.dataQualityFlags.contains('synthetic_demo') ||
        !window.nodeId.startsWith('SYNTHETIC-DEMO-') ||
        !window.serviceId.startsWith('synthetic-')) {
      throw ArgumentError(
        'The cloud threat model accepts only labeled synthetic demo windows.',
      );
    }

    final response = await _callables.httpsCallable('predict_threat').call({
      'demo_only': true,
      'feature_window': window.toMap(),
    });
    final result = _asMap(response.data);
    if (result['simulation_only'] != true || result['persisted'] != false) {
      throw const FormatException(
        'Threat model response did not confirm simulation-only inference.',
      );
    }

    final category = ThreatLabel.values.where(
      (label) => label.wireValue == result['category'],
    );
    if (category.length != 1) {
      throw const FormatException(
        'Threat model returned an unsupported category.',
      );
    }
    final modelVersion = result['model_version'];
    if (modelVersion is! String || modelVersion.trim().isEmpty) {
      throw const FormatException(
        'Threat model response is missing its model version.',
      );
    }

    return ThreatClassifierResult(
      label: category.single,
      confidence: _number(result['confidence']) ?? 0,
      riskWithinForecastHorizon:
          _number(result['risk_within_forecast_horizon']),
      outOfDistribution: result['out_of_distribution'] == true,
      uncertaintyReason: result['uncertainty_reason'] as String?,
      modelVersion: modelVersion,
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Threat model response must be a JSON object.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;
}

class CloudThreatClassifier implements ThreatClassifier {
  final ThreatModelInferenceRepository _repository;

  const CloudThreatClassifier(this._repository);

  @override
  Future<ThreatClassifierResult> classify(ThreatFeatureWindow window) =>
      _repository.classifySyntheticWindow(window);
}
