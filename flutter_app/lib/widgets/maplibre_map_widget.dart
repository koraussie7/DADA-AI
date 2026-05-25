// lib/widgets/maplibre_map_widget.dart
/// MapLibre GL vector tile map widget with custom style support.
///
/// Renders beautifully styled maps using MapLibre GL Native — supports
/// **custom vector style JSON**, runtime theme switching, markers, and
/// full gesture control.
///
/// ## Usage
///
/// ```dart
/// MaplibreMapWidget(
///   style: MapLibreStyle.dadaDark,       // custom DADA dark vector style
///   initialPosition: LatLng(37.5665, 126.9780),
///   markers: [
///     MaplibreMarker(37.5665, 126.9780, label: 'Seoul'),
///   ],
/// )
/// ```
///
/// ## Custom Style
///
/// Pass any valid MapLibre style URL or write a custom JSON to a temp file:
///
/// ```dart
/// MaplibreMapWidget(
///   styleUri: await writeStyleToFile(myCustomJson),
///   ...
/// )
/// ```
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../core/design_system/app_colors.dart';
import '../core/design_system/maplibre_styles.dart';

// ──────────────────────────────────────────────
// Data model for a map marker
// ──────────────────────────────────────────────

/// A marker displayed on the MapLibre map.
class MaplibreMarker {
  final double latitude;
  final double longitude;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final double size;

  const MaplibreMarker(
    this.latitude,
    this.longitude, {
    this.label = '',
    this.subtitle,
    this.icon,
    this.color,
    this.size = 36,
  });
}

// ──────────────────────────────────────────────
// Widget
// ──────────────────────────────────────────────

/// MapLibre GL-powered map widget with custom vector style support.
class MaplibreMapWidget extends StatefulWidget {
  /// Map style to use (from predefined list).
  final MapLibreStyle style;

  /// Custom style URI (overrides [style] if set).
  /// Can be a URL (`https://...`) or file URI (`file://...`).
  final String? styleUri;

  /// Initial camera position.
  final LatLng initialPosition;

  /// Initial zoom level.
  final double initialZoom;

  /// Map markers.
  final List<MaplibreMarker> markers;

  /// When true, the user can pan/zoom the map.
  final bool interactive;

  /// Called when the user taps a marker.
  final void Function(MaplibreMarker marker)? onMarkerTap;

  /// Called when the user taps an empty area on the map.
  final void Function(LatLng point)? onMapTap;

  /// Called once the map style has loaded and is ready.
  final VoidCallback? onMapReady;

  /// Widget height. Defaults to 260.
  final double height;

  /// Background color while the style loads.
  final Color loadingColor;

  /// Whether to show a compass control.
  final bool showCompass;

  /// Whether to show the zoom +/- buttons.
  final bool showZoomControls;

  const MaplibreMapWidget({
    super.key,
    this.style = MapLibreStyle.dadaDark,
    this.styleUri,
    this.initialPosition = const LatLng(37.5665, 126.9780),
    this.initialZoom = 12,
    this.markers = const [],
    this.interactive = true,
    this.onMarkerTap,
    this.onMapTap,
    this.onMapReady,
    this.height = 260,
    this.loadingColor = AppColors.background,
    this.showCompass = true,
    this.showZoomControls = false,
  });

  @override
  State<MaplibreMapWidget> createState() => _MaplibreMapWidgetState();
}

class _MaplibreMapWidgetState extends State<MaplibreMapWidget> {
  MapLibreMapController? _controller;
  String? _resolvedStyleUri;
  bool _ready = false;
  bool _styleLoaded = false;
  final Set<String> _addedSymbols = {};
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _resolveStyle();
  }

  @override
  void didUpdateWidget(MaplibreMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style || oldWidget.styleUri != widget.styleUri) {
      _resolveStyle();
    }
  }

  Future<void> _resolveStyle() async {
    final uri = widget.styleUri ?? await resolveStyleUri(widget.style);
    if (uri != _resolvedStyleUri) {
      _resolvedStyleUri = uri;
      if (_controller != null) {
        await _controller!.setStyle(uri);
      }
    }
  }

  // ── Camera control (public via GlobalKey) ──

  Future<void> animateTo(LatLng point, {double? zoom, double? bearing, double? tilt}) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLng(point),
    );
    if (zoom != null) {
      await _controller?.animateCamera(CameraUpdate.zoomTo(zoom));
    }
  }

  Future<void> fitBounds(LatLngBounds bounds, {double padding = 60}) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding, padding, padding, padding),
    );
  }

  // ── Markers ──

  Future<void> _addMarkers() async {
    if (_controller == null) return;
    for (final marker in widget.markers) {
      final id = 'marker_${_nextId++}';
      if (_addedSymbols.contains(id)) continue;

      await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(marker.latitude, marker.longitude),
          iconImage: 'marker-15',  // default MapLibre marker
          iconSize: marker.size / 15,
          iconColor: marker.color?.value != null
              ? '#${marker.color!.value.toRadixString(16).padLeft(8, '0').substring(0, 6)}'
              : '#F02C56',
          textField: marker.label.isNotEmpty ? marker.label : null,
          textSize: 12,
          textOffset: const Offset(0, -1.5),
          textColor: '#ffffff',
          textHaloColor: '#000000',
          textHaloWidth: 1,
        ),
      );
      _addedSymbols.add(id);
    }
  }

  Future<void> _clearMarkers() async {
    for (final id in _addedSymbols) {
      try {
        await _controller?.removeSymbol(id);
      } catch (_) {}
    }
    _addedSymbols.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── MapLibre GL Map ──
          MapLibreMap(
            onMapCreated: (ctrl) {
              _controller = ctrl;
              if (_resolvedStyleUri != null) {
                ctrl.setStyle(_resolvedStyleUri!);
              }
            },
            onStyleLoadedCallback: () async {
              _styleLoaded = true;
              await _addMarkers();
              if (!_ready) {
                setState(() => _ready = true);
                widget.onMapReady?.call();
              }
            },
            onMapClick: (point, latlng) => widget.onMapTap?.call(latlng),
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: widget.initialZoom,
            ),
            compassEnabled: widget.showCompass,
            scrollEnabled: widget.interactive,
            zoomEnabled: widget.interactive,
            rotateEnabled: widget.interactive,
            tiltEnabled: widget.interactive,
          ),

          // ── Loading indicator ──
          if (!_ready)
            Positioned.fill(
              child: Container(
                color: widget.loadingColor,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),

          // ── Attribution ──
          Positioned(
            bottom: 4,
            right: 8,
            child: GestureDetector(
              onTap: () => _showAttribution(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '\u00a9 OpenFreeMap \u00a9 OSM',
                  style: TextStyle(color: Colors.white60, fontSize: 9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttribution(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Map Data', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Vector tiles \u00a9 OpenFreeMap\n'
          'Data \u00a9 OpenStreetMap contributors\n\n'
          'Custom style: DADA-AI Design System',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clearMarkers();
    _controller?.dispose();
    super.dispose();
  }
}
