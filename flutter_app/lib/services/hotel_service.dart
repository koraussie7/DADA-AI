import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import 'p2p_service.dart';
import 'hybrid_ai_service.dart';

class HotelBookingRequest {
  final String id;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final String location;
  final int? maxBudget;
  final List<String> requirements;
  final String status;
  final DateTime expiresAt;

  HotelBookingRequest({
    required this.id, required this.checkIn, required this.checkOut,
    required this.guests, required this.location,
    this.maxBudget, this.requirements = const [],
    this.status = 'bidding', required this.expiresAt,
  });

  int get remainingSeconds => expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999);
  bool get isExpired => remainingSeconds <= 0;

  factory HotelBookingRequest.fromJson(Map<String, dynamic> j) => HotelBookingRequest(
    id: j['id'] as String? ?? '',
    checkIn: DateTime.tryParse(j['check_in'] as String? ?? '') ?? DateTime.now(),
    checkOut: DateTime.tryParse(j['check_out'] as String? ?? '') ?? DateTime.now(),
    guests: j['guests'] as int? ?? 1,
    location: j['location'] as String? ?? '',
    maxBudget: j['max_budget'] as int?,
    requirements: (j['requirements'] as List?)?.cast<String>() ?? [],
    status: j['status'] as String? ?? 'bidding',
    expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class HotelBid {
  final String id;
  final String hotelId;
  final String hotelName;
  final int price;
  final String message;
  final List<String> amenities;
  final double rating;
  final DateTime submittedAt;

  HotelBid({
    required this.id, required this.hotelId, required this.hotelName,
    required this.price, required this.message,
    this.amenities = const [], this.rating = 0.0,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  factory HotelBid.fromJson(Map<String, dynamic> j) => HotelBid(
    id: j['id'] as String? ?? '',
    hotelId: j['hotel_id'] as String? ?? '',
    hotelName: j['hotel_name'] as String? ?? '',
    price: j['price'] as int? ?? 0,
    message: j['message'] as String? ?? '',
    amenities: (j['amenities'] as List?)?.cast<String>() ?? [],
    rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
    submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? ''),
  );
}

class HotelService extends ChangeNotifier {
  final http.Client _client = http.Client();
  final String _baseUrl = AppConstants.apiBaseUrl;

  HotelBookingRequest? _currentRequest;
  List<HotelBid> _bids = [];
  bool _isBidding = false;
  Timer? _countdownTimer;
  int _remainingSeconds = 300;
  String? _selectedBidId;
  StreamSubscription? _p2pSub;

  HotelBookingRequest? get currentRequest => _currentRequest;
  List<HotelBid> get bids => List.unmodifiable(_bids);
  bool get isBidding => _isBidding;
  int get remainingSeconds => _remainingSeconds;
  String? get selectedBidId => _selectedBidId;
  int get lowestPrice => _bids.isEmpty ? 0 : _bids.map((b) => b.price).reduce((a, b) => a < b ? a : b);

  void listenForBids(P2PService p2p) {
    _p2pSub?.cancel();
    _p2pSub = p2p.incoming.listen((msg) {
      if (msg.type == 'hotel_bid' && _currentRequest != null) {
        try {
          final data = jsonDecode(msg.content) as Map<String, dynamic>;
          if (data['request_id'] == _currentRequest!.id) {
            final bid = HotelBid.fromJson(data['bid'] as Map<String, dynamic>);
            _addBid(bid);
          }
        } catch (_) {}
      }
    });
  }

  Future<String?> createRequest({
    required DateTime checkIn, required DateTime checkOut,
    required int guests, required String location,
    int? maxBudget, List<String> requirements = const [],
  }) async {
    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/hotel/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'check_in': checkIn.toIso8601String(),
          'check_out': checkOut.toIso8601String(),
          'guests': guests,
          'location': location,
          if (maxBudget != null) 'max_budget': maxBudget,
          'requirements': requirements,
        }),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final reqId = data['request_id'] as String;
        _currentRequest = HotelBookingRequest(
          id: reqId, checkIn: checkIn, checkOut: checkOut,
          guests: guests, location: location,
          maxBudget: maxBudget, requirements: requirements,
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        _isBidding = true;
        _bids = [];
        _selectedBidId = null;
        _startCountdown();
        notifyListeners();
        return reqId;
      }
    } catch (e) {
      debugPrint('[Hotel] createRequest error: $e');
    }
    return null;
  }

  void _addBid(HotelBid bid) {
    if (_bids.any((b) => b.id == bid.id)) return;
    _bids.add(bid);
    _bids.sort((a, b) => a.price.compareTo(b.price));
    notifyListeners();
  }

  Future<bool> selectBid(String bidId) async {
    if (_currentRequest == null) return false;
    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/hotel/select/${_currentRequest!.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'hotel_id': bidId}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _selectedBidId = bidId;
        _isBidding = false;
        _countdownTimer?.cancel();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[Hotel] selectBid error: $e');
    }
    return false;
  }

  Future<String?> hermesRecommendation() async {
    if (_bids.isEmpty) return null;
    final ai = HybridAIService();
    final prompt = '호텔 예약 입찰 목록:\n${_bids.map((b) => "- ${b.hotelName}: ${b.price}원, 평점 ${b.rating}, amenities: ${b.amenities.join(", ")}").join("\n")}\n가장 좋은 선택을 추천하고 이유를 설명해줘.';
    final result = await ai.process(prompt);
    return result;
  }

  Future<String> getAiRecommendation({String location = '', int budget = 0, int guests = 1}) async {
    final ai = HybridAIService();
    final prompt = '호텔 추천: location=$location, budget=${budget}원, guests=$guests 명. 적합한 호텔을 추천하고 이유를 설명해줘.';
    final result = await ai.process(prompt);
    return result ?? '추천을 생성할 수 없습니다.';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _isBidding = false;
        _countdownTimer?.cancel();
      }
      notifyListeners();
    });
  }

  void reset() {
    _currentRequest = null;
    _bids = [];
    _isBidding = false;
    _selectedBidId = null;
    _countdownTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _p2pSub?.cancel();
    _countdownTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
