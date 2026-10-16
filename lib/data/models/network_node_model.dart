import 'package:cloud_firestore/cloud_firestore.dart';

enum NodeType { router, Switch, gateway, accessPoint, firewall }

enum NodeStatus { healthy, warning, critical, unknown }

class NetworkNodeModel {
  final String nodeId;
  final String nodeName;
  final String ipAddress;
  final double? latitude;
  final double? longitude;
  final NodeType nodeType;
  final NodeStatus status;
  final String? region;
  final String? zone;
  final bool isActive;
  final String registeredBy;
  final DateTime registeredAt;
  final DateTime? lastSeen;
  final DateTime updatedAt;

  const NetworkNodeModel({
    required this.nodeId,
    required this.nodeName,
    required this.ipAddress,
    this.latitude,
    this.longitude,
    required this.nodeType,
    required this.status,
    this.region,
    this.zone,
    required this.isActive,
    required this.registeredBy,
    required this.registeredAt,
    this.lastSeen,
    required this.updatedAt,
  });

  factory NetworkNodeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final geo = d['location'] as GeoPoint?;

    return NetworkNodeModel(
      nodeId: doc.id,
      nodeName: d['nodeName'] as String? ?? '',
      ipAddress: d['ipAddress'] as String? ?? '',
      latitude: geo?.latitude,
      longitude: geo?.longitude,
      nodeType: _parseNodeType(d['nodeType'] as String?),
      status: _parseNodeStatus(d['status'] as String?),
      region: d['region'] as String?,
      zone: d['zone'] as String?,
      isActive: d['isActive'] as bool? ?? true,
      registeredBy: d['registeredBy'] as String? ?? '',
      registeredAt:
          (d['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static NodeType _parseNodeType(String? v) {
    return NodeType.values.firstWhere(
      (e) => e.name.toLowerCase() == (v ?? '').toLowerCase(),
      orElse: () => NodeType.router,
    );
  }

  static NodeStatus _parseNodeStatus(String? v) {
    return NodeStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == (v ?? '').toLowerCase(),
      orElse: () => NodeStatus.unknown,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;

  String get statusLabel {
    switch (status) {
      case NodeStatus.healthy:
        return 'Healthy';
      case NodeStatus.warning:
        return 'Warning';
      case NodeStatus.critical:
        return 'Critical';
      case NodeStatus.unknown:
        return 'Unknown';
    }
  }
}