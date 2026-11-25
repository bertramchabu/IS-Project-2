enum ThreatLabel {
  benign,
  availabilityAnomaly,
  operationalFault,
  unknown;

  String get wireValue => switch (this) {
        ThreatLabel.benign => 'BENIGN',
        ThreatLabel.availabilityAnomaly => 'AVAILABILITY_ANOMALY',
        ThreatLabel.operationalFault => 'OPERATIONAL_FAULT',
        ThreatLabel.unknown => 'UNKNOWN',
      };
}

class ThreatFeatureWindow {
  static const schemaVersion = 1;
  static const interval = Duration(seconds: 60);

  final String nodeId;
  final String serviceId;
  final DateTime windowStartUtc;
  final DateTime windowEndUtc;
  final Map<String, double> rates;
  final int concurrentConnections;
  final int totalConnections;
  final int failedConnections;
  final int incompleteConnections;
  final double averageConnectionDurationSeconds;
  final Map<String, double> protocolProportions;
  final Map<String, int> destinationPortCounts;
  final Map<String, int> tcpFlagCounts;
  final double sourceAddressEntropy;
  final double destinationAddressEntropy;
  final double topDestinationShare;
  final double successRate;
  final double errorRate;
  final double timeoutRate;
  final double p95LatencyMs;
  final double queueSaturation;
  final String capacityProfile;
  final bool maintenanceWindow;
  final bool recentDeployment;
  final List<String> dataQualityFlags;

  ThreatFeatureWindow({
    required this.nodeId,
    required this.serviceId,
    required this.windowStartUtc,
    required this.windowEndUtc,
    required this.rates,
    required this.concurrentConnections,
    required this.totalConnections,
    required this.failedConnections,
    required this.incompleteConnections,
    required this.averageConnectionDurationSeconds,
    required this.protocolProportions,
    required this.destinationPortCounts,
    required this.tcpFlagCounts,
    required this.sourceAddressEntropy,
    required this.destinationAddressEntropy,
    required this.topDestinationShare,
    required this.successRate,
    required this.errorRate,
    required this.timeoutRate,
    required this.p95LatencyMs,
    required this.queueSaturation,
    required this.capacityProfile,
    required this.maintenanceWindow,
    required this.recentDeployment,
    required this.dataQualityFlags,
  }) {
    if (nodeId.trim().isEmpty || serviceId.trim().isEmpty) {
      throw ArgumentError('nodeId and serviceId must not be empty.');
    }
    if (!windowStartUtc.isUtc || !windowEndUtc.isUtc) {
      throw ArgumentError('Threat feature windows must use UTC timestamps.');
    }
    if (windowEndUtc.difference(windowStartUtc) != interval) {
      throw ArgumentError('Threat feature windows must be exactly 60 seconds.');
    }
    const requiredRates = {
      'packets_per_sec',
      'bytes_per_sec',
      'flow_starts_per_sec',
      'inbound_outbound_ratio',
      'request_rate',
      'response_rate',
    };
    const requiredProtocols = {'tcp', 'udp', 'icmp', 'other'};
    if (!rates.keys.toSet().containsAll(requiredRates) ||
        !protocolProportions.keys.toSet().containsAll(requiredProtocols)) {
      throw ArgumentError('Required threat feature fields are missing.');
    }
    if (rates.values.any((value) => !value.isFinite || value < 0) ||
        protocolProportions.values.any((value) => !value.isFinite)) {
      throw ArgumentError('Feature rates must be finite and non-negative.');
    }
    if ([
      averageConnectionDurationSeconds,
      sourceAddressEntropy,
      destinationAddressEntropy,
      topDestinationShare,
      successRate,
      errorRate,
      timeoutRate,
      p95LatencyMs,
      queueSaturation,
    ].any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Feature values must be finite and non-negative.');
    }
    if (topDestinationShare > 1 ||
        successRate > 1 ||
        errorRate > 1 ||
        timeoutRate > 1 ||
        queueSaturation > 1 ||
        protocolProportions.values.any((value) => value < 0 || value > 1)) {
      throw ArgumentError('Ratios and proportions must be in the range 0..1.');
    }
    final protocolTotal = protocolProportions.values.fold<double>(
      0,
      (total, proportion) => total + proportion,
    );
    if (protocolTotal > 0 && (protocolTotal - 1).abs() > 1e-6) {
      throw ArgumentError('Protocol proportions must sum to 1 when present.');
    }
    if (concurrentConnections < 0 ||
        totalConnections < 0 ||
        failedConnections < 0 ||
        incompleteConnections < 0 ||
        concurrentConnections > totalConnections ||
        failedConnections > totalConnections ||
        incompleteConnections > totalConnections ||
        destinationPortCounts.values.any((count) => count < 0) ||
        tcpFlagCounts.values.any((count) => count < 0) ||
        capacityProfile.trim().isEmpty) {
      throw ArgumentError('Feature counts and context must be valid.');
    }
  }

  bool get isSuitableForClassification =>
      !dataQualityFlags.contains('no_flow_observations') &&
      !dataQualityFlags.contains('clock_offset_exceeds_tolerance') &&
      !dataQualityFlags.contains('out_of_order_observations') &&
      !dataQualityFlags.contains('incomplete_service_health_data') &&
      !dataQualityFlags.contains('service_outcome_counts_mismatch') &&
      rates.values.every((value) => value.isFinite);

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'nodeId': nodeId,
        'serviceId': serviceId,
        'windowStartUtc': windowStartUtc.toIso8601String(),
        'windowEndUtc': windowEndUtc.toIso8601String(),
        'rates': rates,
        'concurrentConnections': concurrentConnections,
        'totalConnections': totalConnections,
        'failedConnections': failedConnections,
        'incompleteConnections': incompleteConnections,
        'averageConnectionDurationSeconds': averageConnectionDurationSeconds,
        'protocolProportions': protocolProportions,
        'destinationPortCounts': destinationPortCounts,
        'tcpFlagCounts': tcpFlagCounts,
        'sourceAddressEntropy': sourceAddressEntropy,
        'destinationAddressEntropy': destinationAddressEntropy,
        'topDestinationShare': topDestinationShare,
        'successRate': successRate,
        'errorRate': errorRate,
        'timeoutRate': timeoutRate,
        'p95LatencyMs': p95LatencyMs,
        'queueSaturation': queueSaturation,
        'capacityProfile': capacityProfile,
        'maintenanceWindow': maintenanceWindow,
        'recentDeployment': recentDeployment,
        'dataQualityFlags': dataQualityFlags,
      };
}
