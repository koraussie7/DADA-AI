// lib/services/massage_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class MassageBid {
  final String id;
  final String therapistId;
  final String therapistName;
  final double price;
  final int estimatedMinutes;
  final String message;
  final double rating;
  final List<String> specialties;
  final DateTime submittedAt;

  MassageBid({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.price,
    required this.estimatedMinutes,
    this.message = '',
    this.rating = 0.0,
    this.specialties = const [],
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  factory MassageBid.fromJson(Map<String, dynamic> j) => MassageBid(
        id: j['id'] as String? ?? '',
        therapistId: j['therapist_id'] as String? ?? '',
        therapistName: j['therapist_name'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        estimatedMinutes: j['estimated_minutes'] as int? ?? 60,
        message: j['message'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
        specialties: (j['specialties'] as List?)?.cast<String>() ?? [],
        submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? ''),
      );
}

class MassageService extends ChangeNotifier {
  final http.Client _client = http.Client();
  final String _baseUrl = AppConstants.apiBaseUrl;

  String? _currentRequestId;
  String _address = '';
  double _lat = 0.0;
  double _lng = 0.0;
  String _serviceType = 'Deep Tissue';
  int _durationMinutes = 60;
  double _maxBudget = 80.0;
  List<MassageBid> _bids = [];
  String? _selectedTherapistId;
  int _remainingSeconds = 300;
  String? _currentStatus;
  Timer? _countdownTimer;
  Timer? _pollTimer;

  String? get currentRequestId => _currentRequestId;
  String get address => _address;
  String get serviceType => _serviceType;
  int get durationMinutes => _durationMinutes;
  double get maxBudget => _maxBudget;
  List<MassageBid> get bids => List.unmodifiable(_bids);
  String? get selectedTherapistId => _selectedTherapistId;
  int get remainingSeconds => _remainingSeconds;
  String? get currentStatus => _currentStatus;
  bool get hasActiveRequest => _currentRequestId != null && _remainingSeconds > 0;
  double get lowestPrice => _bids.isEmpty ? 0 : _bids.map((b) => b.price).reduce((a, b) => a < b ? a : b);

  void setLocation({required String address, required double lat, required double lng}) {
    _address = address;
    _lat = lat;
    _lng = lng;
    notifyListeners();
  }

  void setServiceType(String type) {
    _serviceType = type;
    notifyListeners();
  }

  void setDuration(int minutes) {
    _durationMinutes = minutes.clamp(30, 180);
    notifyListeners();
  }

  void setMaxBudget(double budget) {
    _maxBudget = budget;
    notifyListeners();
  }

  Future<String?> createRequest() async {
    if (_address.isEmpty) return null;

    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/massage/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'address': _address, 'lat': _lat, 'lng': _lng,
          'service_type': _serviceType, 'duration_minutes': _durationMinutes,
          'max_budget': _maxBudget,
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final reqId = data['request_id'] as String;
        _currentRequestId = reqId;
        _bids = [];
        _selectedTherapistId = null;
        _currentStatus = 'bidding';
        _startCountdown();
        notifyListeners();
        return reqId;
      }
    } catch (e) {
      debugPrint('[Massage] createRequest error: $e');
    }
    return null;
  }

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
            .get(Uri.parse('$_baseUrl/massage/bids/$_currentRequestId'))
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final bidsList = (data['bids'] as List?) ?? [];
          bool changed = false;
          for (final b in bidsList) {
            final bid = MassageBid.fromJson(b as Map<String, dynamic>);
            if (!_bids.any((e) => e.id == bid.id)) {
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
        debugPrint('[Massage] listenForBids error: $e');
      }
    });
  }

  Future<bool> selectBid(String bidId) async {
    if (_currentRequestId == null) return false;
    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/massage/select/$_currentRequestId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bid_id': bidId}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _selectedTherapistId = bidId;
        _currentStatus = 'confirmed';
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[Massage] selectBid error: $e');
    }
    return false;
  }

  String hermesRecommendation() {
    if (_bids.isEmpty) return 'No bids yet. Please wait for therapists to respond.';
    final bestPrice = _bids.first;
    final bestValue = _bids.reduce((a, b) {
      final sa = (a.rating * 0.4) + ((1.0 / a.price) * 0.3) + ((1.0 / a.estimatedMinutes) * 0.3);
      final sb = (b.rating * 0.4) + ((1.0 / b.price) * 0.3) + ((1.0 / b.estimatedMinutes) * 0.3);
      return sa >= sb ? a : b;
    });
    return '🤖 **Hermes Recommendation**\n\n'
        'I recommend **${bestValue.therapistName}** '
        '(\$${bestValue.price.toStringAsFixed(2)}, '
        '~${bestValue.estimatedMinutes} min, ⭐${bestValue.rating.toStringAsFixed(1)}).\n\n'
        'Cheapest: **${bestPrice.therapistName}** '
        'at \$${bestPrice.price.toStringAsFixed(2)}.';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        _currentRequestId = null;
        _currentStatus = null;
      }
      notifyListeners();
    });
  }

  void reset() {
    _currentRequestId = null;
    _bids = [];
    _selectedTherapistId = null;
    _remainingSeconds = 300;
    _address = '';
    _currentStatus = null;
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
