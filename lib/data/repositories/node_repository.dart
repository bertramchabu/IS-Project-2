import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/network_node_model.dart';

class NodeRepository {
  final FirebaseFirestore _firestore;

  NodeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of all active nodes (real-time).
  Stream<List<NetworkNodeModel>> watchAllNodes() {
    return _firestore
        .collection('networkNodes')
        .where('isActive', isEqualTo: true)
        .orderBy('nodeName')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => NetworkNodeModel.fromFirestore(doc))
            .toList());
  }

  /// Fetch a single node.
  Future<NetworkNodeModel?> getNode(String nodeId) async {
    final doc =
        await _firestore.collection('networkNodes').doc(nodeId).get();
    if (!doc.exists) return null;
    return NetworkNodeModel.fromFirestore(doc);
  }

  /// Stream of a single node (real-time).
  Stream<NetworkNodeModel?> watchNode(String nodeId) {
    return _firestore
        .collection('networkNodes')
        .doc(nodeId)
        .snapshots()
        .map((doc) => doc.exists
            ? NetworkNodeModel.fromFirestore(doc)
            : null);
  }
}