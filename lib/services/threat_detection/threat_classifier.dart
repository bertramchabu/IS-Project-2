import '../threat_features/threat_feature_window.dart';

class ThreatClassifierResult {
  final ThreatLabel label;
  final double confidence;
  final double? riskWithinForecastHorizon;
  final bool outOfDistribution;
  final String? uncertaintyReason;
  final String modelVersion;

  ThreatClassifierResult({
    required this.label,
    required this.confidence,
    required this.riskWithinForecastHorizon,
    required this.outOfDistribution,
    required this.modelVersion,
    this.uncertaintyReason,
  }) {
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError('Classifier confidence must be in 0..1.');
    }
    if (riskWithinForecastHorizon != null &&
        (!riskWithinForecastHorizon!.isFinite ||
            riskWithinForecastHorizon! < 0 ||
            riskWithinForecastHorizon! > 1)) {
      throw ArgumentError('Forecast-horizon risk must be in 0..1.');
    }
    if (modelVersion.trim().isEmpty) {
      throw ArgumentError('A classifier model version is required.');
    }
  }
}

abstract interface class ThreatClassifier {
  Future<ThreatClassifierResult> classify(ThreatFeatureWindow window);
}

class UnavailableThreatClassifier implements ThreatClassifier {
  const UnavailableThreatClassifier();

  @override
  Future<ThreatClassifierResult> classify(ThreatFeatureWindow window) async {
    return ThreatClassifierResult(
      label: ThreatLabel.unknown,
      confidence: 0,
      riskWithinForecastHorizon: null,
      outOfDistribution: false,
      uncertaintyReason:
          'No validated threat model is configured; rules remain available.',
      modelVersion: 'unavailable',
    );
  }
}
