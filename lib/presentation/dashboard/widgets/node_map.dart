import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/network_node_model.dart';

class NodeMap extends StatelessWidget {
  final List<NetworkNodeModel> nodes;
  final NetworkNodeModel? selectedNode;
  final void Function(NetworkNodeModel node) onNodeTap;

  const NodeMap({
    super.key,
    required this.nodes,
    this.selectedNode,
    required this.onNodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final nodesWithLocation = nodes.where((n) => n.hasLocation).toList();

    if (nodesWithLocation.isEmpty) {
      return const Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.white30),
              SizedBox(height: 16),
              Text('No nodes with location data',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    final center = _computeCenter(nodesWithLocation);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 6.0,
          minZoom: 2,
          maxZoom: 18,
          onTap: (_, __) => FocusScope.of(context).unfocus(),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.strathmore.netvision.netvision_ai',
          ),
          MarkerLayer(
            markers: nodesWithLocation.map((node) {
              final isSelected = node.nodeId == selectedNode?.nodeId;
              return Marker(
                point: LatLng(node.latitude!, node.longitude!),
                width: isSelected ? 48 : 36,
                height: isSelected ? 48 : 36,
                child: GestureDetector(
                  onTap: () => onNodeTap(node),
                  child: Tooltip(
                    message: '${node.nodeName}\n${node.statusLabel}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: _statusColor(node.status),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.black26,
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor(node.status).withValues(alpha: 0.5),
                            blurRadius: isSelected ? 12 : 6,
                            spreadRadius: isSelected ? 4 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _statusIcon(node.nodeType),
                        color: Colors.white,
                        size: isSelected ? 22 : 18,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  LatLng _computeCenter(List<NetworkNodeModel> nodes) {
    final lat = nodes.map((n) => n.latitude!).reduce((a, b) => a + b) /
        nodes.length;
    final lng = nodes.map((n) => n.longitude!).reduce((a, b) => a + b) /
        nodes.length;
    return LatLng(lat, lng);
  }

  Color _statusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.healthy:
        return const Color(0xFF4CAF50);
      case NodeStatus.warning:
        return const Color(0xFFFFC107);
      case NodeStatus.critical:
        return const Color(0xFFF44336);
      case NodeStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _statusIcon(NodeType type) {
    switch (type) {
      case NodeType.router:
        return Icons.router;
      case NodeType.Switch:
        return Icons.swap_horiz;
      case NodeType.gateway:
        return Icons.settings_ethernet;
      case NodeType.accessPoint:
        return Icons.wifi;
      case NodeType.firewall:
        return Icons.security;
    }
  }
}