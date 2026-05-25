// lib/widgets/location_search_widget.dart
/// Reusable OSM-powered location search widget (Google-free).
///
/// Uses OpenStreetMap Nominatim for geocoding & search.
/// No API key required.
///
/// Usage across Food Delivery, Taxi, Massage, Hotel:
/// ```dart
/// LocationSearchWidget(
///   onLocationSelected: (location) {
///     print('Selected: ${location.formattedAddress}');
///     print('  lat: ${location.lat}, lng: ${location.lng}');
///   },
/// )
/// ```
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';

/// Data model for a selected location.
class SelectedLocation {
  final String formattedAddress;
  final double lat;
  final double lng;
  final String placeId;

  const SelectedLocation({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.placeId = '',
  });

  Map<String, dynamic> toJson() => {
        'formatted_address': formattedAddress,
        'lat': lat,
        'lng': lng,
        'place_id': placeId,
      };
}

/// OSM Nominatim geocoding result (replaces Google Places prediction).
class _PlacePrediction {
  final int osmId;
  final String displayName;
  final String mainText;
  final String secondaryText;
  final double lat;
  final double lng;

  const _PlacePrediction({
    required this.osmId,
    required this.displayName,
    required this.mainText,
    required this.secondaryText,
    this.lat = 0,
    this.lng = 0,
  });

  factory _PlacePrediction.fromJson(Map<String, dynamic> json) {
    return _PlacePrediction(
      osmId: json['osm_id'] as int? ?? 0,
      displayName: json['display_name'] as String? ?? '',
      mainText: json['main_text'] as String? ?? '',
      secondaryText: json['secondary_text'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Callback type for location selection.
typedef LocationSelectedCallback = void Function(SelectedLocation location);

class LocationSearchWidget extends StatefulWidget {
  final LocationSelectedCallback onLocationSelected;
  final String? initialAddress;
  final double? initialLat;
  final double? initialLng;
  final String hintText;
  final Color? accentColor;

  const LocationSearchWidget({
    super.key,
    required this.onLocationSelected,
    this.initialAddress,
    this.initialLat,
    this.initialLng,
    this.hintText = 'Search for an address...',
    this.accentColor,
  });

  @override
  State<LocationSearchWidget> createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final http.Client _client = http.Client();
  final String _baseUrl = AppConstants.apiBaseUrl;

  List<_PlacePrediction> _predictions = [];
  SelectedLocation? _selectedLocation;
  bool _isSearching = false;
  bool _isGettingLocation = false;
  bool _showSuggestions = false;
  Timer? _debounce;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _controller.text = widget.initialAddress!;
      if (widget.initialLat != null && widget.initialLng != null) {
        _selectedLocation = SelectedLocation(
          formattedAddress: widget.initialAddress!,
          lat: widget.initialLat!,
          lng: widget.initialLng!,
        );
      }
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _client.close();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Small delay so tap on suggestion registers before hiding
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showSuggestions = false);
      });
    }
  }

  // ── Places Autocomplete ───────────────────────────────────────────────────

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _selectedLocation = null;
    _errorMessage = '';

    if (value.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _showSuggestions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPlaces(value.trim());
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);

    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/api/location-osm/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'limit': 5}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final predictions = (data['predictions'] as List?)
                ?.map((p) => _PlacePrediction.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [];

        if (mounted) {
          setState(() {
            _predictions = predictions;
            _showSuggestions = predictions.isNotEmpty;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) setState(() => _isSearching = false);
      }
    } catch (e) {
      debugPrint('[LocationSearch] search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Search failed. Please try again.';
        });
      }
    }
  }

  // ── Select Prediction → Geocode ───────────────────────────────────────────

  Future<void> _onSelectPrediction(_PlacePrediction prediction) async {
    setState(() {
      _showSuggestions = false;
      _isSearching = true;
      _controller.text = prediction.displayName;
    });

    // Geocode the selected address
    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/api/location-osm/geocode'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'address': prediction.displayName}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final location = SelectedLocation(
          formattedAddress: data['formatted_address'] as String? ??
              prediction.displayName,
          lat: (data['lat'] as num).toDouble(),
          lng: (data['lng'] as num).toDouble(),
          placeId: data['place_id'] as String? ?? '',
        );

        if (mounted) {
          setState(() {
            _selectedLocation = location;
            _isSearching = false;
          });
          widget.onLocationSelected(location);
        }
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _errorMessage = 'Could not pinpoint this address. Try a different one.';
          });
        }
      }
    } catch (e) {
      debugPrint('[LocationSearch] geocode error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Geocoding failed. Please try again.';
        });
      }
    }
  }

  // ── Get Current Location ──────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _errorMessage = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isGettingLocation = false;
            _errorMessage =
                'Location services are disabled. Please enable them in your browser settings.';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isGettingLocation = false;
              _errorMessage = 'Location permissions are denied.';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isGettingLocation = false;
            _errorMessage =
                'Location permissions are permanently denied. Update your browser settings.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Reverse geocode
      try {
        final resp = await _client
            .post(
              Uri.parse('$_baseUrl/api/location-osm/reverse'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'lat': position.latitude,
                'lng': position.longitude,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200 && mounted) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final location = SelectedLocation(
            formattedAddress: data['formatted_address'] as String? ??
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            lat: (data['lat'] as num).toDouble(),
            lng: (data['lng'] as num).toDouble(),
            placeId: data['place_id'] as String? ?? '',
          );

          setState(() {
            _selectedLocation = location;
            _controller.text = location.formattedAddress;
            _isGettingLocation = false;
          });
          widget.onLocationSelected(location);
        } else {
          // Use raw coordinates
          final location = SelectedLocation(
            formattedAddress:
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            lat: position.latitude,
            lng: position.longitude,
          );

          if (mounted) {
            setState(() {
              _selectedLocation = location;
              _controller.text = location.formattedAddress;
              _isGettingLocation = false;
            });
            widget.onLocationSelected(location);
          }
        }
      } catch (e) {
        // Fallback to raw coordinates
        final location = SelectedLocation(
          formattedAddress:
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          lat: position.latitude,
          lng: position.longitude,
        );

        if (mounted) {
          setState(() {
            _selectedLocation = location;
            _controller.text = location.formattedAddress;
            _isGettingLocation = false;
          });
          widget.onLocationSelected(location);
        }
      }
    } catch (e) {
      debugPrint('[LocationSearch] getCurrentLocation error: $e');
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
          _errorMessage = 'Could not get your location. Try searching manually.';
        });
      }
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  void _clearSelection() {
    setState(() {
      _controller.clear();
      _selectedLocation = null;
      _predictions = [];
      _showSuggestions = false;
      _errorMessage = '';
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? const Color(0xFF6366F1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Search Field ──
        _buildSearchField(accent),

        // ── Selected Location Info ──
        if (_selectedLocation != null) ...[
          const SizedBox(height: 8),
          _buildSelectedLocationCard(accent),
        ],

        // ── Error Message ──
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildErrorMessage(),
        ],

        // ── Suggestions Overlay ──
        if (_showSuggestions && _predictions.isNotEmpty)
          _buildSuggestionsList(accent),
      ],
    );
  }

  Widget _buildSearchField(Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedLocation != null
              ? const Color(0xFF22C55E).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        onChanged: _onTextChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          prefixIcon: _isGettingLocation
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                )
              : const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
          suffixIcon: _controller.text.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "Use my location" button
                    if (_selectedLocation == null)
                      IconButton(
                        icon: Icon(
                          Icons.my_location,
                          color: _isGettingLocation
                              ? Colors.grey
                              : const Color(0xFF6366F1),
                          size: 22,
                        ),
                        tooltip: 'Use my current location',
                        onPressed:
                            _isGettingLocation ? null : _getCurrentLocation,
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: _clearSelection,
                    ),
                  ],
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSelectedLocationCard(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF22C55E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedLocation!.formattedAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedLocation!.lat.toStringAsFixed(5)}, ${_selectedLocation!.lng.toStringAsFixed(5)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(Color accent) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _predictions.length,
                  itemBuilder: (context, index) {
                    final p = _predictions[index];
                    return _buildSuggestionItem(p, accent);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(_PlacePrediction prediction, Color accent) {
    return InkWell(
      onTap: () => _onSelectPrediction(prediction),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.place, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (prediction.mainText.isNotEmpty)
                    Text(
                      prediction.mainText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    prediction.secondaryText.isNotEmpty
                        ? prediction.secondaryText
                        : prediction.displayName,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
