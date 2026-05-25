// lib/services/osm_location_service.dart
/// OSM-based location service — Google-free alternative to LocationService.
///
/// Uses OpenStreetMap data via:
///   - Nominatim API (geocoding, search)
///   - Overpass API (nearby places search)
///   - Geolocator (device GPS)
///
/// No API key required. Works globally.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';

/// A place result from OpenStreetMap (Overpass API).
class OsmPlace {
  final int osmId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String type;
  final String category;
  final double? rating;
  final double distance;

  const OsmPlace({
    required this.osmId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.type = 'node',
    this.category = 'other',
    this.rating,
    this.distance = 0,
  });

  factory OsmPlace.fromJson(Map<String, dynamic> json) {
    return OsmPlace(
      osmId: json['osm_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'node',
      category: json['category'] as String? ?? 'other',
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }

  /// Emoji based on OSM category.
  String get emoji {
    switch (category) {
      case 'restaurant':
      case 'fast_food':
      case 'food_court':
        return '🍽️';
      case 'hotel':
      case 'hostel':
      case 'motel':
      case 'guest_house':
        return '🏨';
      case 'spa':
      case 'sauna':
        return '💆';
      case 'cafe':
        return '☕';
      case 'bar':
      case 'pub':
      case 'nightclub':
        return '🍸';
      case 'hospital':
      case 'clinic':
      case 'doctors':
        return '🏥';
      case 'fitness_centre':
      case 'sports_centre':
        return '💪';
      case 'fuel':
        return '⛽';
      case 'park':
      case 'garden':
        return '🌳';
      case 'shop':
        return '🛍️';
      case 'bank':
        return '🏦';
      case 'pharmacy':
        return '💊';
      case 'police':
        return '👮';
      case 'school':
      case 'university':
        return '📚';
      case 'cinema':
        return '🎬';
      case 'library':
        return '📖';
      case 'place_of_worship':
        return '⛪';
      default:
        return '📍';
    }
  }
}

/// Category filter for nearby search (maps to OSM amenity/leisure keys).
class OsmPlaceCategory {
  final String type;
  final String label;
  final String emoji;
  final int radius;

  const OsmPlaceCategory({
    required this.type,
    required this.label,
    required this.emoji,
    this.radius = 1500,
  });

  static const List<OsmPlaceCategory> all = [
    OsmPlaceCategory(type: 'restaurant', label: 'Restaurants', emoji: '🍽️', radius: 1500),
    OsmPlaceCategory(type: 'hotel', label: 'Hotels', emoji: '🏨', radius: 3000),
    OsmPlaceCategory(type: 'spa', label: 'Spa & Massage', emoji: '💆', radius: 2000),
    OsmPlaceCategory(type: 'cafe', label: 'Cafes', emoji: '☕', radius: 1000),
    OsmPlaceCategory(type: 'bar', label: 'Bars & Nightlife', emoji: '🍸', radius: 1500),
    OsmPlaceCategory(type: 'gym', label: 'Gyms', emoji: '💪', radius: 2000),
    OsmPlaceCategory(type: 'hospital', label: 'Hospitals', emoji: '🏥', radius: 3000),
    OsmPlaceCategory(type: 'park', label: 'Parks', emoji: '🌳', radius: 2000),
    OsmPlaceCategory(type: 'pharmacy', label: 'Pharmacies', emoji: '💊', radius: 1500),
  ];
}

/// OSM-based Location Service — replaces Google Places API.
///
/// Uses OSM backend proxy at /api/location-osm/* or falls back to
/// direct Nominatim/Overpass API calls.
class OsmLocationService extends ChangeNotifier {
  final http.Client _client = http.Client();
  final String _baseUrl = AppConstants.apiBaseUrl;

  // Current state
  List<OsmPlace> _nearbyPlaces = [];
  bool _isLoading = false;
  String? _error;
  OsmPlaceCategory _selectedCategory = OsmPlaceCategory.all[0];
  Position? _currentPosition;

  // Getters
  List<OsmPlace> get nearbyPlaces => _nearbyPlaces;
  bool get isLoading => _isLoading;
  String? get error => _error;
  OsmPlaceCategory get selectedCategory => _selectedCategory;
  Position? get currentPosition => _currentPosition;
  double get currentLat => _currentPosition?.latitude ?? 37.5665;
  double get currentLng => _currentPosition?.longitude ?? 126.9780;

  /// Get user's current location via GPS.
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      _currentPosition = pos;
      notifyListeners();
      return pos;
    } catch (e) {
      debugPrint('[OsmLocationService] position error: $e');
      return null;
    }
  }

  /// Search nearby places via backend OSM proxy.
  Future<void> searchNearby({
    OsmPlaceCategory? category,
    double? lat,
    double? lng,
    int? radius,
  }) async {
    final cat = category ?? _selectedCategory;
    if (category != null) _selectedCategory = category;

    final useLat = lat ?? currentLat;
    final useLng = lng ?? currentLng;
    final rad = radius ?? cat.radius;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try backend proxy first
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/api/location-osm/nearby'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': useLat,
              'lng': useLng,
              'radius': rad,
              'type': cat.type,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _nearbyPlaces = (data['results'] as List?)
                ?.map((p) => OsmPlace.fromJson(p as Map<String, dynamic>))
                .toList() ?? [];

        // Calculate distances
        if (_currentPosition != null) {
          final userLat = _currentPosition!.latitude;
          final userLng = _currentPosition!.longitude;
          for (var i = 0; i < _nearbyPlaces.length; i++) {
            final place = _nearbyPlaces[i];
            _nearbyPlaces[i] = OsmPlace(
              osmId: place.osmId,
              name: place.name,
              address: place.address,
              lat: place.lat,
              lng: place.lng,
              type: place.type,
              category: place.category,
              rating: place.rating,
              distance: Geolocator.distanceBetween(
                userLat, userLng, place.lat, place.lng,
              ),
            );
          }
          // Sort by distance
          _nearbyPlaces.sort((a, b) => a.distance.compareTo(b.distance));
        }
      } else {
        _error = 'Search failed (${resp.statusCode})';
      }
    } catch (e) {
      debugPrint('[OsmLocationService] backend search error: $e');
      // Fallback: direct Overpass API call
      await _directOverpassSearch(useLat, useLng, rad, cat.type);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Direct Overpass API call (fallback if backend proxy is unavailable).
  Future<void> _directOverpassSearch(
    double lat, double lng, int radius, String type,
  ) async {
    try {
      // Map type to OSM filter
      String osmFilter;
      switch (type) {
        case 'restaurant': osmFilter = '["amenity"~"restaurant|fast_food|food_court"]'; break;
        case 'hotel': osmFilter = '["tourism"~"hotel|hostel|motel|guest_house"]'; break;
        case 'spa': osmFilter = '["amenity"="spa"]["leisure"="sauna"]'; break;
        case 'cafe': osmFilter = '["amenity"="cafe"]'; break;
        case 'bar': osmFilter = '["amenity"~"bar|pub|nightclub"]'; break;
        case 'gym': osmFilter = '["leisure"="fitness_centre"]'; break;
        case 'hospital': osmFilter = '["amenity"~"hospital|clinic|doctors"]'; break;
        case 'park': osmFilter = '["leisure"~"park|garden"]'; break;
        case 'pharmacy': osmFilter = '["amenity"="pharmacy"]'; break;
        default: osmFilter = '["amenity"="$type"]';
      }

      final overpassQuery = '''
      [out:json][timeout:15];
      (node$osmFilter(around:$radius,$lat,$lng);
       way$osmFilter(around:$radius,$lat,$lng););
      out center 25;
      ''';

      final resp = await _client.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': overpassQuery},
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];
        final results = <OsmPlace>[];

        for (final el in elements.take(40)) {
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] as String?
              ?? tags['brand'] as String?
              ?? tags['operator'] as String?
              ?? '';

          final elLat = (el['lat'] ?? el['center']?['lat'] ?? 0).toDouble();
          final elLon = (el['lon'] ?? el['center']?['lon'] ?? 0).toDouble();
          if (elLat == 0 && elLon == 0) continue;

          final addrParts = <String>[];
          for (final key in ['addr:street', 'addr:housenumber', 'addr:city']) {
            final val = tags[key] as String?;
            if (val != null && val.isNotEmpty) addrParts.add(val);
          }

          final category = tags['amenity'] as String? ??
              tags['leisure'] as String? ??
              tags['shop'] as String? ??
              'other';

          results.add(OsmPlace(
            osmId: (el['id'] as int?) ?? 0,
            name: name.isNotEmpty ? name : '$category (${el['id']})',
            address: addrParts.join(', '),
            lat: elLat,
            lng: elLon,
            type: el['type'] as String? ?? 'node',
            category: category,
          ));
        }

        _nearbyPlaces = results;
      } else {
        _error = 'Direct OSM search failed';
      }
    } catch (e) {
      debugPrint('[OsmLocationService] direct search error: $e');
      _error = 'Could not search nearby places (no network?)';
    }
  }

  /// Set category and re-search.
  Future<void> setCategory(OsmPlaceCategory category) async {
    if (category.type == _selectedCategory.type) return;
    await searchNearby(category: category);
  }

  /// Search by text query via Nominatim.
  Future<List<OsmPlace>> searchByText(String query, {int limit = 5}) async {
    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/api/location-osm/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'limit': limit}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final predictions = (data['predictions'] ?? data['results']) as List?;
        return predictions
            ?.map((p) => OsmPlace.fromJson({
                  ...p as Map<String, dynamic>,
                  'osm_id': p['osm_id'] ?? 0,
                  'name': p['display_name'] ?? p['name'] ?? '',
                  'address': p['display_name'] ?? p['address'] ?? '',
                }))
            .toList() ?? [];
      }
    } catch (e) {
      debugPrint('[OsmLocationService] text search error: $e');
    }
    return [];
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
