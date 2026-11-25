import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/core/utils/threshold_validation.dart';

void main() {
  test('accepts valid threshold policy values', () {
    expect(
      ThresholdValidation.validate(
        globalThreshold: 0.70,
        reductionThreshold: 0.30,
        reductionPercentage: 90,
        healthyInterval: 10,
      ),
      isNull,
    );
  });

  test('mirrors server bounds', () {
    expect(
      ThresholdValidation.validate(
        globalThreshold: 0.49,
        reductionThreshold: 0.30,
        reductionPercentage: 90,
        healthyInterval: 10,
      ),
      isNotNull,
    );
    expect(
      ThresholdValidation.validate(
        globalThreshold: 0.70,
        reductionThreshold: 0.70,
        reductionPercentage: 90,
        healthyInterval: 10,
      ),
      isNotNull,
    );
    expect(
      ThresholdValidation.validate(
        globalThreshold: 0.70,
        reductionThreshold: 0.30,
        reductionPercentage: 96,
        healthyInterval: 10,
      ),
      isNotNull,
    );
  });
}
