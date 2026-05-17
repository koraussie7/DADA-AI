// lib/services/taxi_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class TaxiBid {
  final String id;
  final String driverId;
  final String driverName;
  final double price;
  final int estimatedMinutes;
  final String message;
  final double rating;
  final String carModel;
  final String carColor;
  final DateTime submittedAt;

  TaxiBid({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.price,
    required this.estimatedMinutes,
    this.message = '',
    this.rating = 0.0,
    this.carModel = '',
    this.carColor = '',
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  factory TaxiBid.fromJson(Map<String, dynamic> j) => TaxiBid(
        id: j['id'] as String? ?? '',
        driverId: j['driver_id'] as String? ?? '',
        driverName: j['driver_name'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        estimatedMinutes: j['estimated_minutes'] as int? ?? 10,
        message: j['message'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
        carModel: j['car_model'] as String? ?? '',
        carColor: j['car_color'] as String? ?? '',
        submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? ''),
      );
}

class TaxiService extends ChangeNotifier {
  final http.Client _client = http.Client();
  final String _baseUrl = AppConstants.apiBaseUrl;

  String? _currentRequestId;
  String _pickupAddress = '';
  double _pickupLat = 0.0;
  double _pickupLng = 0.0;
  String _dropoffAddress = '';
  double _dropoffLat = 0.0;
  double _dropoffLng = 0.0;
  int _passengers = 1;
  double _maxBudget = 20.0;
  List<TaxiBid> _bids = [];
  String? _selectedDriverId;
  int _remainingSeconds = 300;
  String? _currentRideStatus;
  Timer? _countdownTimer;
  Timer? _pollTimer;

  // ── Getters ──
  String? get currentRequestId => _currentRequestId;
  String get pickupAddress => _pickupAddress;
  String get dropoffAddress => _dropoffAddress;
  int get passengers => _passengers;
  double get maxBudget => _maxBudget;
  List<TaxiBid> get bids => List.unmodifiable(_bids);
  String? get selectedDriverId => _selectedDriverId;
  int get remainingSeconds => _remainingSeconds;
  String? get currentRideStatus => _currentRideStatus;
  bool get hasActiveRequest => _currentRequestId != null && _remainingSeconds > 0;
  double get lowestPrice => _bids.isEmpty ? 0 : _bids.map((b) => b.price).reduce((a, b) => a < b ? a : b);

  // ── Setter ──
  void setPickupLocation({required String address, required double lat, required double lng}) {
    _pickupAddress = address;
    _pickupLat = lat;
    _pickupLng = lng;
    notifyListeners();
  }

  void setDropoffLocation({required String address, required double lat, required double lng}) {
    _dropoffAddress = address;
    _dropoffLat = lat;
    _dropoffLng = lng;
    notifyListeners();
  }

  void setPassengers(int count) {
    _passengers = count.clamp(1, 8);
    notifyListeners();
  }

  void setMaxBudget(double budget) {
    _maxBudget = budget;
    notifyListeners();
  }

  // ── Create Ride Request ──
  Future<String?> createRideRequest() async {
    if (_pickupAddress.isEmpty || _dropoffAddress.isEmpty) {
      debugPrint('[Taxi] Pickup and dropoff required.');
      return null;
    }

    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/taxi/request'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pickup_address': _pickupAddress,
              'pickup_lat': _pickupLat,
              'pickup_lng': _pickupLng,
              'dropoff_address': _dropoffAddress,
              'dropoff_lat': _dropoffLat,
              'dropoff_lng': _dropoffLng,
              'passengers': _passengers,
              'max_budget': _maxBudget,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final reqId = data['request_id'] as String;
        _currentRequestId = reqId;
        _bids = [];
        _selectedDriverId = null;
        _currentRideStatus = 'bidding';
        _startCountdown();
        notifyListeners();
        debugPrint('[Taxi] Ride request created: $reqId');
        return reqId;
      } else {
        debugPrint('[Taxi] createRideRequest failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[Taxi] createRideRequest error: $e');
    }
    return null;
  }

  // ── Listen for Bids ──
  void listenForBids() {
    _pollTimer?.cancel();
    if (_currentRequestId == null) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_currentRequestId == null || _remainingSeconds <= 0) {
        _pollTimer?.cancel();
        return;
      }

      try {
        final resp = await _client
            .get(Uri.parse('$_baseUrl/taxi/bids/$_currentRequestId'))
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final bidsList = (data['bids'] as List?) ?? [];
          bool changed = false;

          for (final b in bidsList) {
            final bid = TaxiBid.fromJson(b as Map<String, dynamic>);
            if (!_bids.any((existing) => existing.id == bid.id)) {
              _bids.add(bid);
              changed = true;
            }
          }

          if (changed) {
            _bids.sort((a, b) => a.price.compareTo(b.price));
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('[Taxi] listenForBids error: $e');
      }
    });
  }

  // ── Select a Bid ──
  Future<bool> selectBid(String bidId) async {
    if (_currentRequestId == null) return false;

    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/taxi/select/$_currentRequestId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'bid_id': bidId}),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        _selectedDriverId = bidId;
        _currentRideStatus = 'confirmed';
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        notifyListeners();
        debugPrint('[Taxi] Driver selected: $bidId');
        return true;
      }
    } catch (e) {
      debugPrint('[Taxi] selectBid error: $e');
    }
    return false;
  }

  // ── AI Recommendation ──
  String hermesRecommendation() {
    if (_bids.isEmpty) {
      return 'No bids available yet. Please wait for drivers to respond.';
    }
    final bestPrice = _bids.first;
    final bestValue = _bids.reduce((a, b) {
      final scoreA = (a.rating * 0.4) + ((1.0 / a.price) * 0.3) +
          ((1.0 / a.estimatedMinutes) * 0.3);
      final scoreB = (b.rating * 0.4) + ((1.0 / b.price) * 0.3) +
          ((1.0 / b.estimatedMinutes) * 0.3);
      return scoreA >= scoreB ? a : b;
    });

    return '🤖 **Hermes Recommendation**\n\n'
        'Based on price, rating, and ETA, '
        'I recommend **${bestValue.driverName}** '
        '(\$${bestValue.price.toStringAsFixed(2)}, '
        '~${bestValue.estimatedMinutes} min, '
        '⭐${bestValue.rating.toStringAsFixed(1)}).\n\n'
        'For the cheapest ride, choose **${bestPrice.driverName}** '
        'at \$${bestPrice.price.toStringAsFixed(2)} '
        '(~${bestPrice.estimatedMinutes} min).';
  }

  // ── Timer ──
  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        _currentRequestId = null;
        _currentRideStatus = null;
      }
      notifyListeners();
    });
  }

  // ── Reset ──
  void reset() {
    _currentRequestId = null;
    _bids = [];
    _selectedDriverId = null;
    _remainingSeconds = 300;
    _pickupAddress = '';
    _dropoffAddress = '';
    _currentRideStatus = null;
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
