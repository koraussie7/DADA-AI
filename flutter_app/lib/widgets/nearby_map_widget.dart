// lib/widgets/nearby_map_widget.dart
/// Nearby Places radius search map widget for Home screen.
/// Shows OpenStreetMap with nearby restaurants/hotels/more in a radius.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/design_system/app_colors.dart';
import '../services/osm_location_service.dart';

class NearbyMapWidget extends StatefulWidget {
  const NearbyMapWidget({super.key});

  @override
  State<NearbyMapWidget> createState() => _NearbyMapWidgetState();
}

class _NearbyMapWidgetState extends State<NearbyMapWidget> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final svc = context.read<OsmLocationService>();
      svc.getCurrentPosition().then((_) {
        svc.searchNearby();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<OsmLocationService>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Places',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Find restaurants, hotels & more near you',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (svc.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),

          // ── Category Chips ──
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: OsmPlaceCategory.all.map((cat) {
                final selected = cat.type == svc.selectedCategory.type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => svc.setCategory(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        '${cat.emoji} ${cat.label}',
                        style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── Map ──
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  // The map
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(svc.currentLat, svc.currentLng),
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.jawg.io/jawg-dark/{z}/{x}/{y}{r}.png?access-token=BM0Bph5V4bMwGQJYlELndLwWQJqCTqgYH7Odx6qfrLVUPJKLIYg9bLtFPySWoYQb',
                        userAgentPackageName: 'com.liberty.reach',
                      ),

                      // Radius circle
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(svc.currentLat, svc.currentLng),
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderColor: AppColors.primary.withValues(alpha: 0.3),
                            borderStrokeWidth: 2,
                            radius: svc.selectedCategory.radius * 1000.0,
                          ),
                        ],
                      ),

                      // User location dot + nearby place markers
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(svc.currentLat, svc.currentLng),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ...svc.nearbyPlaces.map((place) => Marker(
                                point: LatLng(place.lat, place.lng),
                                width: 36,
                                height: 36,
                                child: _PlaceMarker(place: place),
                              )),
                        ],
                      ),
                    ],
                  ),

                  // Gradient overlay at bottom for readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.surface.withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tap on marker overlay
                  if (svc.nearbyPlaces.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: _PlaceCountBar(count: svc.nearbyPlaces.length),
                    ),
                ],
              ),
            ),
          ),

          // ── Place List (top 3 as preview) ──
          if (svc.nearbyPlaces.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  ...svc.nearbyPlaces.take(3).map((place) => _PlaceRow(place: place)),
                  if (svc.nearbyPlaces.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => _showAllPlaces(svc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+${svc.nearbyPlaces.length - 3} more places',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── Empty state ──
          if (!svc.isLoading && svc.nearbyPlaces.isEmpty && svc.error == null)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Enable location to find nearby places',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
            ),

          if (svc.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  svc.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllPlaces(OsmLocationService svc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Nearby Places',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${svc.nearbyPlaces.length} found',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: svc.nearbyPlaces.length,
                itemBuilder: (ctx, i) {
                  final place = svc.nearbyPlaces[i];
                  return _PlaceRow(place: place);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini marker on the map ──

class _PlaceMarker extends StatelessWidget {
  final OsmPlace place;
  const _PlaceMarker({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Text(
          place.emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// ── Count bar overlaid on map ──

class _PlaceCountBar extends StatelessWidget {
  final int count;
  const _PlaceCountBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Tap marker for details — $count places found',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Single place row in the list ──

class _PlaceRow extends StatelessWidget {
  final OsmPlace place;
  const _PlaceRow({required this.place});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(place.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.address,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (place.rating != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFF22C55E)),
                    const SizedBox(width: 2),
                    Text(
                      place.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
