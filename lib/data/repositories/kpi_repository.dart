import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kpi_metric_model.dart';

class KpiRepository {
  final FirebaseFirestore _firestore;

  KpiRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream the last N KPI metrics for a node and metric type.
  Stream<List<KpiMetricModel>> watchRecentKpi({
    required String nodeId,
    required MetricType metricType,
    int limit = 100,
  }) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('kpiMetrics')
        .where('metricTypeId', isEqualTo: _metricTypeToId(metricType))
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => KpiMetricModel.fromFirestore(doc, nodeId))
          .toList();
      // Reverse so oldest first for chart rendering
      return list.reversed.toList();
    });
  }

  /// Stream the last N metrics of all types combined (for the "latest snapshot" widget).
  Stream<List<KpiMetricModel>> watchLatestPerType(String nodeId) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('kpiMetrics')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => KpiMetricModel.fromFirestore(doc, nodeId))
            .toList());
  }

  String _metricTypeToId(MetricType type) {
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
}