import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/network_node_model.dart';

class NodeMap extends StatefulWidget {
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
  State<NodeMap> createState() => _NodeMapState();
}

class _NodeMapState extends State<NodeMap> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(covariant NodeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    if (_locationSignature(oldWidget.nodes) !=
        _locationSignature(widget.nodes)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitNodes());
    } else if (oldWidget.selectedNode?.nodeId !=
        widget.selectedNode?.nodeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locatedNodes = widget.nodes.where((node) => node.hasLocation).toList();
    if (locatedNodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 56, color: Colors.white30),
            SizedBox(height: 12),
            Text(
              'Node locations will appear here',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    final bounds = _computeBounds(locatedNodes);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(56),
            ),
            minZoom: 2,
            maxZoom: 18,
            onMapReady: _handleMapReady,
            onTap: (_, __) => FocusScope.of(context).unfocus(),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.strathmore.netvision.netvision_ai',
              maxNativeZoom: 19,
            ),
            MarkerLayer(
              markers: locatedNodes.map((node) {
                final selected =
                    node.nodeId == widget.selectedNode?.nodeId;
                final color = _statusColor(node.status);
                return Marker(
                  point: LatLng(node.latitude!, node.longitude!),
                  width: selected ? 48 : 38,
                  height: selected ? 48 : 38,
                  child: GestureDetector(
                    onTap: () => widget.onNodeTap(node),
                    child: Tooltip(
                      message:
                          '${node.nodeName}\n${node.statusLabel} • ${node.nodeType.name}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.black54,
                            width: selected ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.55),
                              blurRadius: selected ? 14 : 8,
                              spreadRadius: selected ? 4 : 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _statusIcon(node.nodeType),
                          color: Colors.white,
                          size: selected ? 21 : 18,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution('CARTO'),
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _MapControl(
                icon: Icons.add,
                label: 'Zoom in',
                onPressed: () => _zoomBy(1),
              ),
              const SizedBox(height: 4),
              _MapControl(
                icon: Icons.remove,
                label: 'Zoom out',
                onPressed: () => _zoomBy(-1),
              ),
              const SizedBox(height: 4),
              _MapControl(
                icon: Icons.fit_screen,
                label: 'Fit all nodes',
                onPressed: _fitNodes,
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _mapLegend(locatedNodes.length),
        ),
      ],
    );
  }

  Widget _mapLegend(int visibleNodes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$visibleNodes located ${visibleNodes == 1 ? 'node' : 'nodes'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _legendItem('Healthy', const Color(0xFF22C55E)),
          _legendItem('Warning', const Color(0xFFF59E0B)),
          _legendItem('Critical', const Color(0xFFEF4444)),
          _legendItem('Unknown', const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _handleMapReady() {
    _mapReady = true;
    _centerSelected();
  }

  void _centerSelected() {
    final selected = widget.selectedNode;
    if (!_mapReady || selected == null || !selected.hasLocation) return;
    _mapController.move(
      LatLng(selected.latitude!, selected.longitude!),
      9,
    );
  }

  void _fitNodes() {
    final locatedNodes = widget.nodes.where((node) => node.hasLocation).toList();
    if (!_mapReady || locatedNodes.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: _computeBounds(locatedNodes),
        padding: const EdgeInsets.all(56),
      ),
    );
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(2, 18).toDouble(),
    );
  }

  String _locationSignature(List<NetworkNodeModel> nodes) => nodes
      .where((node) => node.hasLocation)
      .map((node) => '${node.nodeId}:${node.latitude}:${node.longitude}')
      .join('|');

  LatLngBounds _computeBounds(List<NetworkNodeModel> nodes) {
    final latitudes = nodes.map((node) => node.latitude!).toList();
    final longitudes = nodes.map((node) => node.longitude!).toList();
    var south = latitudes.reduce((a, b) => a < b ? a : b);
    var north = latitudes.reduce((a, b) => a > b ? a : b);
    var west = longitudes.reduce((a, b) => a < b ? a : b);
    var east = longitudes.reduce((a, b) => a > b ? a : b);

    if (north - south < 0.05) {
      south = (south - 0.025).clamp(-90, 90).toDouble();
      north = (north + 0.025).clamp(-90, 90).toDouble();
    }
    if (east - west < 0.05) {
      west = (west - 0.025).clamp(-180, 180).toDouble();
      east = (east + 0.025).clamp(-180, 180).toDouble();
    }
    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }

  Color _statusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.healthy:
        return const Color(0xFF22C55E);
      case NodeStatus.warning:
        return const Color(0xFFF59E0B);
      case NodeStatus.critical:
        return const Color(0xFFEF4444);
      case NodeStatus.unknown:
        return const Color(0xFF64748B);
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

class _MapControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MapControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6111827),
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
