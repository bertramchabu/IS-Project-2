import 'package:cloud_firestore/cloud_firestore.dart';

enum MetricType {
  latency,
  jitter,
  packetLoss,
  retransmissionRate,
  signalStrength
}

enum DataSource { simulated, csvReplay, api, fileUpload }

enum DataQuality { good, fair, poor }

class KpiMetricModel {
  final String metricId;
  final String nodeId;
  final MetricType metricType;
  final double value;
  final String unit;
  final DateTime timestamp;
  final DataSource source;
  final DataQuality? quality;

  const KpiMetricModel({
    required this.metricId,
    required this.nodeId,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    this.quality,
  });

  factory KpiMetricModel.fromFirestore(DocumentSnapshot doc, String nodeId) {
    final d = doc.data() as Map<String, dynamic>;
    return KpiMetricModel(
      metricId: doc.id,
      nodeId: nodeId,
      metricType: _parseMetricType(d['metricTypeId'] as String?),
      value: (d['value'] as num?)?.toDouble() ?? 0.0,
      unit: d['unit'] as String? ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: _parseSource(d['source'] as String?),
      quality:
          d['quality'] != null ? _parseQuality(d['quality'] as String?) : null,
    );
  }

  static MetricType _parseMetricType(String? v) {
    final normalized = (v ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'latency':
        return MetricType.latency;
      case 'jitter':
        return MetricType.jitter;
      case 'packetloss':
      case 'packet_loss':
      case 'packet-loss':
        return MetricType.packetLoss;
      case 'retransmissionrate':
      case 'retransmission_rate':
      case 'retransmission-rate':
        return MetricType.retransmissionRate;
      case 'signalstrength':
      case 'signal_strength':
      case 'signal-strength':
        return MetricType.signalStrength;
      default:
        return MetricType.latency;
    }
  }

  static DataSource _parseSource(String? v) {
    final normalized = (v ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'simulated':
      case 'simulation':
      case 'demo':
        return DataSource.simulated;
      case 'csvreplay':
      case 'csv_replay':
      case 'csv-replay':
        return DataSource.csvReplay;
      case 'api':
      case 'rest':
      case 'cloudfunction':
      case 'firebase':
        return DataSource.api;
      case 'fileupload':
      case 'file_upload':
      case 'file-upload':
        return DataSource.fileUpload;
      default:
        return DataSource.simulated;
    }
  }

  static DataQuality _parseQuality(String? v) {
    final normalized = (v ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'good':
      case 'healthy':
        return DataQuality.good;
      case 'fair':
      case 'warning':
      case 'moderate':
        return DataQuality.fair;
      case 'poor':
      case 'critical':
      case 'bad':
        return DataQuality.poor;
      default:
        return DataQuality.good;
    }
  }

  String get metricTypeId {
    switch (metricType) {
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

  String get displayName {
    switch (metricType) {
      case MetricType.latency:
        return 'Latency';
      case MetricType.jitter:
        return 'Jitter';
      case MetricType.packetLoss:
        return 'Packet Loss';
      case MetricType.retransmissionRate:
        return 'Retransmission';
      case MetricType.signalStrength:
        return 'Signal Strength';
    }
  }
}
