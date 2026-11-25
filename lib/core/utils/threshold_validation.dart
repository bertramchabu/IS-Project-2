class ThresholdValidation {
  static String? validate({
    required double globalThreshold,
    required double reductionThreshold,
    required int reductionPercentage,
    required double healthyInterval,
  }) {
    if (globalThreshold < 0.50 || globalThreshold > 0.95) {
      return 'Global threshold must be between 50% and 95%.';
    }
    if (reductionThreshold < 0.10 ||
        reductionThreshold >= globalThreshold) {
      return 'Reduction threshold must be at least 10% and below the global threshold.';
    }
    if (reductionPercentage < 50 || reductionPercentage > 95) {
      return 'Reduction percentage must be between 50% and 95%.';
    }
    if (healthyInterval < 1 || healthyInterval > 60) {
      return 'Healthy interval must be between 1 and 60 seconds.';
    }
    return null;
  }
}
