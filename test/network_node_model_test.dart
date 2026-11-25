import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netvision_ai/data/models/network_node_model.dart';

NetworkNodeModel _node({double? latitude, double? longitude}) {
  final now = DateTime.utc(2026);
  return NetworkNodeModel(
    nodeId: 'node-1',
    nodeName: 'Test node',
    ipAddress: '192.0.2.1',
    latitude: latitude,
    longitude: longitude,
    nodeType: NodeType.router,
    status: NodeStatus.healthy,
    isActive: true,
    registeredBy: 'test',
    registeredAt: now,
    updatedAt: now,
  );
}

void main() {
  test('reads coordinates stored as separate numeric fields', () {
    final node = NetworkNodeModel.fromMap('node-1', {
      'latitude': -1.2921,
      'longitude': 36.8219,
    });

    expect(node.latitude, -1.2921);
    expect(node.longitude, 36.8219);
    expect(node.hasLocation, isTrue);
  });

  test('reads coordinates stored as a Firestore GeoPoint', () {
    final node = NetworkNodeModel.fromMap('node-1', {
      'location': const GeoPoint(-1.2921, 36.8219),
    });

    expect(node.latitude, -1.2921);
    expect(node.longitude, 36.8219);
    expect(node.hasLocation, isTrue);
  });

  test('accepts valid geographic coordinates', () {
    expect(_node(latitude: -90, longitude: 180).hasLocation, isTrue);
    expect(_node(latitude: 0, longitude: 0).hasLocation, isTrue);
  });

  test('rejects missing and out-of-range coordinates', () {
    expect(_node().hasLocation, isFalse);
    expect(_node(latitude: 91, longitude: 0).hasLocation, isFalse);
    expect(_node(latitude: 0, longitude: -181).hasLocation, isFalse);
  });

  test('rejects non-finite coordinates', () {
    expect(_node(latitude: double.nan, longitude: 0).hasLocation, isFalse);
    expect(_node(latitude: 0, longitude: double.infinity).hasLocation, isFalse);
  });
}
