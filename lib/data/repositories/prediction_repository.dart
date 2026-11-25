import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prediction_model.dart';

class PredictionRepository {
  final FirebaseFirestore _firestore;

  PredictionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream the latest prediction for a node.
  Stream<PredictionModel?> watchLatestPrediction(String nodeId) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('predictions')
        .orderBy('predictionTimestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return PredictionModel.fromFirestore(snap.docs.first, nodeId);
    });
  }

  /// Stream the last N predictions for a node.
  Stream<List<PredictionModel>> watchPredictionHistory(
    String nodeId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('predictions')
        .orderBy('predictionTimestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PredictionModel.fromFirestore(doc, nodeId))
            .toList()
            .reversed
            .toList());
  }

  /// Fetch the most recent prediction for a node (one-shot).
  Future<PredictionModel?> getLatestPrediction(String nodeId) async {
    final snap = await _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .collection('predictions')
        .orderBy('predictionTimestamp', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return PredictionModel.fromFirestore(snap.docs.first, nodeId);
  }
}
