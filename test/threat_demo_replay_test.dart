import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/data/models/threat_feed_item.dart';
import 'package:netvision_ai/services/threat_detection/threat_classifier.dart';
import 'package:netvision_ai/services/threat_features/threat_demo_replay.dart';
import 'package:netvision_ai/services/threat_features/threat_feature_window.dart';

class _RecordingThreatClassifier implements ThreatClassifier {
  final List<ThreatFeatureWindow> windows = [];

  @override
  Future<ThreatClassifierResult> classify(ThreatFeatureWindow window) async {
    windows.add(window);
    return ThreatClassifierResult(
      label: ThreatLabel.benign,
      confidence: 0.81,
      riskWithinForecastHorizon: 0.12,
      outOfDistribution: false,
      modelVersion: 'cloud-test-model',
    );
  }
}

void main() {
  test('runs synthetic flows through the production rule decision pipeline',
      () async {
    final results = await ThreatDemoReplay().generate();
    final assessments = results.map((result) => result.assessment).toList();

    expect(assessments, hasLength(3));
    expect(
      assessments.map((assessment) => assessment.category),
      [
        ThreatLabel.unknown,
        ThreatLabel.availabilityAnomaly,
        ThreatLabel.operationalFault,
      ],
    );
    expect(assessments[1].modelVersion, 'rules-v1');
    expect(assessments[2].modelVersion, 'rules-v1');
    expect(assessments.first.confidence, isNull);
    expect(assessments.first.uncertaintyReason,
        contains('No validated threat model'));

    final feedItems = assessments.map(ThreatFeedItem.fromDemoAssessment);
    expect(feedItems.every((item) => item.isSyntheticDemo), isTrue);
    expect(feedItems.every((item) => item.status == 'SIMULATED'), isTrue);
    expect(
      feedItems
          .every((item) => item.dataQualityFlags.contains('synthetic_demo')),
      isTrue,
    );
    expect(assessments.every((item) => item.modelPrediction != null), isTrue);
    expect(
      results.every(
        (result) =>
            result.featureWindow.dataQualityFlags.contains('synthetic_demo'),
      ),
      isTrue,
    );
  });

  test('sends each synthetic scenario through the configured cloud classifier',
      () async {
    final classifier = _RecordingThreatClassifier();

    final results = await ThreatDemoReplay(
      modelClassifier: classifier,
    ).generate();

    expect(classifier.windows, hasLength(3));
    expect(
      classifier.windows.every(
          (window) => window.dataQualityFlags.contains('synthetic_demo')),
      isTrue,
    );
    expect(
      results.every((result) =>
          result.assessment.modelPrediction?.modelVersion ==
          'cloud-test-model'),
      isTrue,
    );
  });
}
