// lib/screens/maplibre_map_screen.dart
/// Full‑page MapLibre GL map screen with custom vector style support.
///
/// Demonstrates:
///   - Custom DADA-AI dark vector style (no API key required)
///   - Runtime style switching (dark ↔ light)
///   - Multiple markers with labels
///   - Current location (via GeoLocator)
///   - Bottom sheet for marker details
library;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../core/design_system/app_colors.dart';
import '../core/design_system/maplibre_styles.dart';
import '../services/osm_location_service.dart';
import '../widgets/maplibre_map_widget.dart';

/// Full‑screen vector map page that showcases MapLibre GL + custom style.
class MaplibreMapScreen extends StatefulWidget {
  const MaplibreMapScreen({super.key});

  @override
  State<MaplibreMapScreen> createState() => _MaplibreMapScreenState();
}

class _MaplibreMapScreenState extends State<MaplibreMapScreen> {
  final GlobalKey<_MaplibreMapWidgetState> _mapKey = GlobalKey();
  final OsmLocationService _locationService = OsmLocationService();
  MapLibreStyle _currentStyle = MapLibreStyle.dadaDark;
  List<MaplibreMarker> _markers = [];
  bool _locating = false;

  // ── Demo POIs around Seoul ──

  static const List<MaplibreMarker> _defaultMarkers = [
    MaplibreMarker(37.5665, 126.9780, label: 'Seoul', subtitle: 'City Hall'),
    MaplibreMarker(37.5716, 126.9766, label: 'Gyeongbokgung', subtitle: 'Palace'),
    MaplibreMarker(37.5796, 126.9770, label: 'Bukchon', subtitle: 'Hanok Village'),
    MaplibreMarker(37.5512, 126.9882, label: 'N Seoul Tower', subtitle: 'Landmark'),
    MaplibreMarker(37.5113, 127.0982, label: 'Lotte World', subtitle: 'Theme Park'),
    MaplibreMarker(37.4777, 126.6249, label: 'Incheon', subtitle: 'Airport'),
  ];

  @override
  void initState() {
    super.initState();
    _markers = List.from(_defaultMarkers);
  }

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      final marker = MaplibreMarker(
        pos.latitude, pos.longitude,
        label: 'You',
        color: AppColors.primary,
        icon: Icons.my_location,
      );
      setState(() {
        _markers = [marker, ..._defaultMarkers];
      });
      // Animate to user's location
      _mapKey.currentState?.animateTo(
        LatLng(pos.latitude, pos.longitude),
        zoom: 14,
      );
    }
    if (mounted) setState(() => _locating = false);
  }

  void _toggleStyle() {
    setState(() {
      _currentStyle = _currentStyle == MapLibreStyle.dadaDark
          ? MapLibreStyle.dadaLight
          : MapLibreStyle.dadaDark;
    });
  }

  void _showMarkerDetail(MaplibreMarker marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    marker.icon ?? Icons.location_on,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (marker.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          marker.subtitle!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    '${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate Here'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vector Map'),
        actions: [
          // Locate me
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
            onPressed: _locateMe,
            tooltip: 'My Location',
          ),
          // Toggle style
          IconButton(
            icon: Icon(
              _currentStyle == MapLibreStyle.dadaDark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: _toggleStyle,
            tooltip: 'Toggle Style',
          ),
          // Style info
          PopupMenuButton<MapLibreStyle>(
            icon: const Icon(Icons.style),
            tooltip: 'Change Style',
            onSelected: (style) => setState(() => _currentStyle = style),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: MapLibreStyle.dadaDark,
                child: Text('DADA Dark (Custom)'),
              ),
              const PopupMenuItem(
                value: MapLibreStyle.dadaLight,
                child: Text('DADA Light (Custom)'),
              ),
              const PopupMenuItem(
                value: MapLibreStyle.openFreeMap,
                child: Text('OpenFreeMap Liberty'),
              ),
              const PopupMenuItem(
                value: MapLibreStyle.openFreeMapDark,
                child: Text('OpenFreeMap Dark'),
              ),
            ],
          ),
        ],
      ),
      body: MaplibreMapWidget(
        key: _mapKey,
        style: _currentStyle,
        initialPosition: const LatLng(37.5665, 126.9780),
        initialZoom: 11,
        markers: _markers,
        height: double.infinity,
        onMarkerTap: _showMarkerDetail,
        onMapReady: () => debugPrint('[MapLibreMapScreen] style loaded'),
      ),
    );
  }
}
