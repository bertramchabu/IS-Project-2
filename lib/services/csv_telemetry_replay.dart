import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../data/models/kpi_metric_model.dart';

class CsvTelemetryReplay {
  CsvTelemetryReplay._(this._samples)
      : sourceIds = _samples.keys.toList()..sort();

  static const assetPath = 'model/data/network_kpi_dataset.csv';
  static const _metricColumns = <String, MetricType>{
    'latency': MetricType.latency,
    'jitter': MetricType.jitter,
    'packet_loss': MetricType.packetLoss,
    'retransmission_rate': MetricType.retransmissionRate,
    'signal_strength': MetricType.signalStrength,
  };

  final Map<String, List<Map<MetricType, double>>> _samples;
  final List<String> sourceIds;
  final Map<String, int> _positions = {};

  static Future<CsvTelemetryReplay> load({AssetBundle? bundle}) async {
    final sourceBundle = bundle ?? rootBundle;
    return CsvTelemetryReplay.fromCsv(
      await sourceBundle.loadString(assetPath),
    );
  }

  factory CsvTelemetryReplay.fromCsv(String csv) {
    final normalizedCsv =
        csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final rows = const CsvToListConverter(eol: '\n').convert(normalizedCsv);
    if (rows.length < 2) {
      throw const FormatException('Telemetry CSV has no sample rows.');
    }

    final headers = rows.first.map((value) => value.toString().trim()).toList();
    final columnIndexes = <String, int>{
      for (var i = 0; i < headers.length; i++) headers[i]: i,
    };
    for (final column in ['node_id', ..._metricColumns.keys]) {
      if (!columnIndexes.containsKey(column)) {
        throw FormatException('Telemetry CSV is missing the "$column" column.');
      }
    }

    final samples = <String, List<Map<MetricType, double>>>{};
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final line = rowIndex + 1;
      if (row.length != headers.length) {
        throw FormatException(
            'Telemetry CSV row $line has the wrong number of columns.');
      }

      final sourceId = row[columnIndexes['node_id']!].toString().trim();
      if (sourceId.isEmpty) {
        throw FormatException('Telemetry CSV row $line has an empty node_id.');
      }

      final sample = <MetricType, double>{};
      for (final entry in _metricColumns.entries) {
        final column = entry.key;
        final value = double.tryParse(
          row[columnIndexes[column]!].toString(),
        );
        if (value == null || !value.isFinite) {
          throw FormatException(
            'Telemetry CSV row $line has an invalid "$column" value.',
          );
        }
        sample[entry.value] = value;
      }
      samples.putIfAbsent(sourceId, () => []).add(sample);
    }

    if (samples.isEmpty) {
      throw const FormatException(
          'Telemetry CSV contains no usable locations.');
    }
    return CsvTelemetryReplay._(samples);
  }

  List<KpiMetricModel> sample({
    required int locationIndex,
    required String nodeId,
    required DateTime timestamp,
  }) {
    if (locationIndex < 0 || locationIndex >= sourceIds.length) {
      throw RangeError.index(locationIndex, sourceIds, 'locationIndex');
    }

    final sourceId = sourceIds[locationIndex];
    final sourceSamples = _samples[sourceId]!;
    final position = _positions[sourceId] ?? 0;
    final values = sourceSamples[position];
    _positions[sourceId] = (position + 1) % sourceSamples.length;

    return values.entries.map((entry) {
      return KpiMetricModel(
        metricId:
            'csv-$nodeId-${timestamp.microsecondsSinceEpoch}-${entry.key.name}',
        nodeId: nodeId,
        metricType: entry.key,
        value: entry.value,
        unit: _unitFor(entry.key),
        timestamp: timestamp,
        source: DataSource.csvReplay,
      );
    }).toList();
  }

  String _unitFor(MetricType type) {
    switch (type) {
      case MetricType.latency:
      case MetricType.jitter:
        return 'ms';
      case MetricType.packetLoss:
      case MetricType.retransmissionRate:
        return '%';
      case MetricType.signalStrength:
        return 'dBm';
    }
  }
}
