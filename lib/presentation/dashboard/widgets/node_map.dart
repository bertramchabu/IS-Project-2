// node_map.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/models/network_node_model.dart';
import '../../widgets/web_safe_backdrop_blur.dart';

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
  GoogleMapController? _mapController;
  double _currentZoom = 5;

  static const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0b111a"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#91a5c2"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0b111a"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#1f2a3a"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#141e30"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#7186a4"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1f2a3a"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#141e30"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8da2c0"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#141e30"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#05080e"}]}
]
''';

  List<NetworkNodeModel> get _locatedNodes =>
      widget.nodes.where((node) => node.hasLocation).toList();

  @override
  void didUpdateWidget(covariant NodeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_locationSignature(oldWidget.nodes) !=
        _locationSignature(widget.nodes)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitNodes());
    } else if (oldWidget.selectedNode?.nodeId != widget.selectedNode?.nodeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locatedNodes = _locatedNodes;
    final center = _initialCenter(locatedNodes);

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 5),
          style: _darkMapStyle,
          markers: locatedNodes.map(_markerFor).toSet(),
          onMapCreated: _onMapCreated,
          onCameraMove: (position) => _currentZoom = position.zoom,
          onTap: (_) => FocusScope.of(context).unfocus(),
          mapToolbarEnabled: false,
          compassEnabled: false,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          buildingsEnabled: true,
          trafficEnabled: false,
          minMaxZoomPreference: const MinMaxZoomPreference(2, 19),
        ),
        if (locatedNodes.isEmpty)
          const Center(
            child: _GlassSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_searching_rounded,
                        size: 28, color: Color(0xFF9FB3D1)),
                    SizedBox(height: 8),
                    Text('Add node coordinates to view the network map',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        Positioned(left: 12, top: 12, child: _mapLegend(locatedNodes)),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _MapControl(
                  icon: Icons.add_rounded,
                  label: 'Zoom in',
                  onPressed: () => _zoomBy(1)),
              const SizedBox(height: 8),
              _MapControl(
                  icon: Icons.remove_rounded,
                  label: 'Zoom out',
                  onPressed: () => _zoomBy(-1)),
              const SizedBox(height: 8),
              _MapControl(
                  icon: Icons.fit_screen_rounded,
                  label: 'Fit all nodes',
                  onPressed: _fitNodes),
            ],
          ),
        ),
      ],
    );
  }

  Marker _markerFor(NetworkNodeModel node) {
    final selected = node.nodeId == widget.selectedNode?.nodeId;
    return Marker(
      markerId: MarkerId(node.nodeId),
      position: LatLng(node.latitude!, node.longitude!),
      icon: BitmapDescriptor.defaultMarkerWithHue(_statusHue(node.status)),
      alpha: selected ? 1 : 0.88,
      zIndexInt: selected ? 2 : 1,
      infoWindow: InfoWindow(
          title: node.nodeName,
          snippet: '${node.statusLabel} · ${node.nodeType.name}'),
      onTap: () => widget.onNodeTap(node),
    );
  }

  Widget _mapLegend(List<NetworkNodeModel> nodes) {
    final selected = widget.selectedNode;
    return _GlassSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${nodes.length} located ${nodes.length == 1 ? 'node' : 'nodes'}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            if (selected != null && selected.hasLocation) ...[
              const SizedBox(height: 4),
              Text(selected.nodeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 8),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: Color(0xFF00FF9D), label: 'Healthy'),
                SizedBox(width: 10),
                _LegendDot(color: Color(0xFFFFB300), label: 'Warning'),
                SizedBox(width: 10),
                _LegendDot(color: Color(0xFFFF0055), label: 'Critical'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_locatedNodes.length > 1) {
        _fitNodes();
      } else {
        _centerSelected();
      }
    });
  }

  void _centerSelected() {
    final selected = widget.selectedNode;
    final controller = _mapController;
    if (controller == null || selected == null || !selected.hasLocation) return;
    controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(selected.latitude!, selected.longitude!), 11));
  }

  void _fitNodes() {
    final nodes = _locatedNodes;
    final controller = _mapController;
    if (controller == null || nodes.isEmpty) return;
    if (nodes.length == 1) {
      final node = nodes.single;
      controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(node.latitude!, node.longitude!), 11));
      return;
    }
    controller
        .animateCamera(CameraUpdate.newLatLngBounds(_computeBounds(nodes), 64));
  }

  void _zoomBy(double delta) {
    final controller = _mapController;
    if (controller == null) return;
    controller.animateCamera(
        CameraUpdate.zoomTo((_currentZoom + delta).clamp(2, 19).toDouble()));
  }

  String _locationSignature(List<NetworkNodeModel> nodes) => nodes
      .where((node) => node.hasLocation)
      .map((node) => '${node.nodeId}:${node.latitude}:${node.longitude}')
      .join('|');

  LatLngBounds _computeBounds(List<NetworkNodeModel> nodes) {
    final latitudes = nodes.map((node) => node.latitude!).toList();
    final longitudes = nodes.map((node) => node.longitude!).toList();
    var south = latitudes.reduce(math.min);
    var north = latitudes.reduce(math.max);
    var west = longitudes.reduce(math.min);
    var east = longitudes.reduce(math.max);

    if (north - south < 0.02) {
      south = (south - 0.01).clamp(-90, 90).toDouble();
      north = (north + 0.01).clamp(-90, 90).toDouble();
    }
    if (east - west < 0.02) {
      west = (west - 0.01).clamp(-180, 180).toDouble();
      east = (east + 0.01).clamp(-180, 180).toDouble();
    }

    return LatLngBounds(
        southwest: LatLng(south, west), northeast: LatLng(north, east));
  }

  LatLng _initialCenter(List<NetworkNodeModel> nodes) {
    if (nodes.isEmpty) return const LatLng(-1.2921, 36.8219);
    final selected = widget.selectedNode;
    if (selected != null && selected.hasLocation) {
      return LatLng(selected.latitude!, selected.longitude!);
    }
    final latitude =
        nodes.map((node) => node.latitude!).reduce((a, b) => a + b) /
            nodes.length;
    final longitude =
        nodes.map((node) => node.longitude!).reduce((a, b) => a + b) /
            nodes.length;
    return LatLng(latitude, longitude);
  }

  double _statusHue(NodeStatus status) {
    switch (status) {
      case NodeStatus.healthy:
        return BitmapDescriptor.hueGreen;
      case NodeStatus.warning:
        return BitmapDescriptor.hueOrange;
      case NodeStatus.critical:
        return BitmapDescriptor.hueRed;
      case NodeStatus.unknown:
        return BitmapDescriptor.hueAzure;
    }
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)
                ])),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ],
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  const _GlassSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: WebSafeBackdropBlur(
        sigma: 16,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 6))
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _MapControl(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
