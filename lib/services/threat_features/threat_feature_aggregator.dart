import 'dart:math' as math;

import 'threat_feature_window.dart';

enum ThreatProtocol { tcp, udp, icmp, other }

enum ThreatConnectionOutcome { successful, failed, incomplete }

class ThreatWindowContext {
  final String capacityProfile;
  final bool isSyntheticDemo;
  final bool maintenanceWindow;
  final bool recentDeployment;
  final Duration observedClockOffset;

  const ThreatWindowContext({
    required this.capacityProfile,
    this.isSyntheticDemo = false,
    this.maintenanceWindow = false,
    this.recentDeployment = false,
    this.observedClockOffset = Duration.zero,
  });
}

/// One metadata-only flow observation. Address values must be short-lived,
/// non-reversible buckets; raw addresses and packet payloads are not accepted.
class ThreatFlowObservation {
  final DateTime startedAtUtc;
  final String nodeId;
  final String serviceId;
  final String sourceBucket;
  final String destinationBucket;
  final int destinationPort;
  final ThreatProtocol protocol;
  final int packetsInbound;
  final int packetsOutbound;
  final int bytesInbound;
  final int bytesOutbound;
  final Map<String, int> tcpFlags;
  final double durationSeconds;
  final ThreatConnectionOutcome outcome;
  final int requestCount;
  final int responseCount;
  final int successfulRequests;
  final int failedRequests;
  final int timedOutRequests;
  final double? latencyMs;
  final double? queueSaturation;

  const ThreatFlowObservation({
    required this.startedAtUtc,
    required this.nodeId,
    required this.serviceId,
    required this.sourceBucket,
    required this.destinationBucket,
    required this.destinationPort,
    required this.protocol,
    required this.packetsInbound,
    required this.packetsOutbound,
    required this.bytesInbound,
    required this.bytesOutbound,
    required this.tcpFlags,
    required this.durationSeconds,
    required this.outcome,
    this.requestCount = 0,
    this.responseCount = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.timedOutRequests = 0,
    this.latencyMs,
    this.queueSaturation,
  });
}

class ThreatFeatureAggregator {
  static const clockOffsetTolerance = Duration(seconds: 2);
  static const _allowedTcpFlags = {
    'SYN',
    'ACK',
    'FIN',
    'RST',
    'PSH',
    'URG',
    'ECE',
    'CWR',
  };
  static const _topDestinationPortLimit = 10;

  ThreatFeatureWindow aggregate({
    required DateTime windowStartUtc,
    required String nodeId,
    required String serviceId,
    required List<ThreatFlowObservation> observations,
    required ThreatWindowContext context,
  }) {
    if (!windowStartUtc.isUtc ||
        windowStartUtc.second != 0 ||
        windowStartUtc.millisecond != 0 ||
        windowStartUtc.microsecond != 0) {
      throw ArgumentError(
        'windowStartUtc must be UTC and aligned to a minute boundary.',
      );
    }
    if (nodeId.trim().isEmpty || serviceId.trim().isEmpty) {
      throw ArgumentError('nodeId and serviceId must not be empty.');
    }
    _validateContext(context);

    final windowEnd = windowStartUtc.add(ThreatFeatureWindow.interval);
    final flags = <String>{};
    if (context.isSyntheticDemo) flags.add('synthetic_demo');
    if (context.observedClockOffset.abs() > clockOffsetTolerance) {
      flags.add('clock_offset_exceeds_tolerance');
    }
    if (observations.isEmpty) flags.add('no_flow_observations');

    DateTime? previousTimestamp;
    for (final observation in observations) {
      _validateObservation(observation);
      if (observation.nodeId != nodeId || observation.serviceId != serviceId) {
        throw ArgumentError('All observations must share node and service.');
      }
      if (!observation.startedAtUtc.isUtc ||
          observation.startedAtUtc.isBefore(windowStartUtc) ||
          !observation.startedAtUtc.isBefore(windowEnd)) {
        throw ArgumentError('Observation timestamp is outside the UTC window.');
      }
      if (previousTimestamp != null &&
          observation.startedAtUtc.isBefore(previousTimestamp)) {
        flags.add('out_of_order_observations');
      }
      previousTimestamp = observation.startedAtUtc;
    }

    if (observations.any(
        (item) => item.latencyMs == null || item.queueSaturation == null)) {
      flags.add('incomplete_service_health_data');
    }
    if (observations.any((item) =>
        item.requestCount !=
        item.successfulRequests +
            item.failedRequests +
            item.timedOutRequests)) {
      flags.add('service_outcome_counts_mismatch');
    }

    final flowCount = observations.length;
    final inboundPackets =
        observations.fold<int>(0, (sum, item) => sum + item.packetsInbound);
    final outboundPackets =
        observations.fold<int>(0, (sum, item) => sum + item.packetsOutbound);
    final inboundBytes =
        observations.fold<int>(0, (sum, item) => sum + item.bytesInbound);
    final outboundBytes =
        observations.fold<int>(0, (sum, item) => sum + item.bytesOutbound);
    final totalBytes = inboundBytes + outboundBytes;
    final requestCount =
        observations.fold<int>(0, (sum, item) => sum + item.requestCount);
    final responseCount =
        observations.fold<int>(0, (sum, item) => sum + item.responseCount);
    final successfulRequests =
        observations.fold<int>(0, (sum, item) => sum + item.successfulRequests);
    final failedRequests =
        observations.fold<int>(0, (sum, item) => sum + item.failedRequests);
    final timedOutRequests =
        observations.fold<int>(0, (sum, item) => sum + item.timedOutRequests);

    final protocols = <ThreatProtocol, int>{
      for (final protocol in ThreatProtocol.values) protocol: 0,
    };
    final ports = <int, int>{};
    final flagsByName = <String, int>{};
    final sources = <String, int>{};
    final destinations = <String, int>{};
    for (final observation in observations) {
      protocols.update(
        observation.protocol,
        (count) => count + 1,
      );
      ports.update(
        observation.destinationPort,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      sources.update(
        observation.sourceBucket,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      destinations.update(
        observation.destinationBucket,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      observation.tcpFlags.forEach((name, count) {
        final normalizedName = name.toUpperCase();
        flagsByName.update(normalizedName, (current) => current + count,
            ifAbsent: () => count);
      });
    }

    final protocolTotal = protocols.values.fold<int>(0, (sum, n) => sum + n);
    final destinationCount =
        destinations.values.fold<int>(0, (sum, n) => sum + n);
    final requestDenominator = requestCount == 0 ? 1 : requestCount;
    final safeObservations = observations.toList()
      ..sort((left, right) => left.startedAtUtc.compareTo(right.startedAtUtc));
    final durations =
        safeObservations.map((item) => item.durationSeconds).toList();
    final latencies = safeObservations
        .map((item) => item.latencyMs)
        .whereType<double>()
        .toList()
      ..sort();
    final queueValues = safeObservations
        .map((item) => item.queueSaturation)
        .whereType<double>()
        .toList();

    return ThreatFeatureWindow(
      nodeId: nodeId,
      serviceId: serviceId,
      windowStartUtc: windowStartUtc,
      windowEndUtc: windowEnd,
      rates: {
        'packets_per_sec': (inboundPackets + outboundPackets) / 60,
        'bytes_per_sec': totalBytes / 60,
        'flow_starts_per_sec': flowCount / 60,
        'inbound_outbound_ratio':
            outboundBytes == 0 ? 0 : inboundBytes / outboundBytes,
        'request_rate': requestCount / 60,
        'response_rate': responseCount / 60,
      },
      concurrentConnections: _maximumConcurrentConnections(observations),
      totalConnections: flowCount,
      failedConnections: observations
          .where((item) => item.outcome == ThreatConnectionOutcome.failed)
          .length,
      incompleteConnections: observations
          .where((item) => item.outcome == ThreatConnectionOutcome.incomplete)
          .length,
      averageConnectionDurationSeconds: durations.isEmpty
          ? 0
          : durations.reduce((a, b) => a + b) / durations.length,
      protocolProportions: {
        for (final protocol in ThreatProtocol.values)
          protocol.name:
              protocolTotal == 0 ? 0 : protocols[protocol]! / protocolTotal,
      },
      destinationPortCounts: {
        for (final entry in (ports.entries.toList()
              ..sort((left, right) => right.value.compareTo(left.value)))
            .take(_topDestinationPortLimit))
          entry.key.toString(): entry.value,
      },
      tcpFlagCounts: flagsByName,
      sourceAddressEntropy: _entropy(sources),
      destinationAddressEntropy: _entropy(destinations),
      topDestinationShare: destinationCount == 0
          ? 0
          : destinations.values.reduce(math.max) / destinationCount,
      successRate: successfulRequests / requestDenominator,
      errorRate: failedRequests / requestDenominator,
      timeoutRate: timedOutRequests / requestDenominator,
      p95LatencyMs: _percentile95(latencies),
      queueSaturation: queueValues.isEmpty ? 0 : queueValues.reduce(math.max),
      capacityProfile: context.capacityProfile,
      maintenanceWindow: context.maintenanceWindow,
      recentDeployment: context.recentDeployment,
      dataQualityFlags: flags.toList()..sort(),
    );
  }

  void _validateObservation(ThreatFlowObservation observation) {
    if (observation.nodeId.trim().isEmpty ||
        observation.serviceId.trim().isEmpty ||
        observation.sourceBucket.trim().isEmpty ||
        observation.destinationBucket.trim().isEmpty) {
      throw ArgumentError('Observation identifiers and buckets are required.');
    }
    if (observation.destinationPort < 0 ||
        observation.destinationPort > 65535 ||
        observation.packetsInbound < 0 ||
        observation.packetsOutbound < 0 ||
        observation.bytesInbound < 0 ||
        observation.bytesOutbound < 0 ||
        observation.requestCount < 0 ||
        observation.responseCount < 0 ||
        observation.successfulRequests < 0 ||
        observation.failedRequests < 0 ||
        observation.timedOutRequests < 0 ||
        observation.tcpFlags.values.any((count) => count < 0) ||
        observation.tcpFlags.keys.any(
          (name) => !_allowedTcpFlags.contains(name.toUpperCase()),
        )) {
      throw ArgumentError('Flow counts and destination ports must be valid.');
    }
    if (!observation.durationSeconds.isFinite ||
        observation.durationSeconds < 0 ||
        (observation.latencyMs != null &&
            (!observation.latencyMs!.isFinite || observation.latencyMs! < 0)) ||
        (observation.queueSaturation != null &&
            (!observation.queueSaturation!.isFinite ||
                observation.queueSaturation! < 0 ||
                observation.queueSaturation! > 1))) {
      throw ArgumentError('Duration, latency, or saturation is invalid.');
    }
  }

  void _validateContext(ThreatWindowContext context) {
    if (context.capacityProfile.trim().isEmpty) {
      throw ArgumentError('capacityProfile must not be empty.');
    }
  }

  int _maximumConcurrentConnections(List<ThreatFlowObservation> observations) {
    final events = <(DateTime, int)>[];
    for (final item in observations) {
      if (item.durationSeconds == 0) continue;
      events.add((item.startedAtUtc, 1));
      events.add((
        item.startedAtUtc.add(
          Duration(microseconds: (item.durationSeconds * 1000000).round()),
        ),
        -1,
      ));
    }
    events.sort((left, right) {
      final byTime = left.$1.compareTo(right.$1);
      return byTime != 0 ? byTime : left.$2.compareTo(right.$2);
    });

    var concurrent = 0;
    var maximum = 0;
    for (final event in events) {
      concurrent += event.$2;
      maximum = math.max(maximum, concurrent);
    }
    return maximum;
  }

  double _entropy(Map<String, int> counts) {
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return 0;
    return counts.values.fold<double>(0, (entropy, count) {
      final probability = count / total;
      return entropy - probability * (math.log(probability) / math.ln2);
    });
  }

  double _percentile95(List<double> sortedValues) {
    if (sortedValues.isEmpty) return 0;
    final index = ((sortedValues.length - 1) * 0.95).ceil();
    return sortedValues[index];
  }
}
