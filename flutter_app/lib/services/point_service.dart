import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PointService {
  static final PointService _instance = PointService._();
  factory PointService() => _instance;
  PointService._();

  String _baseUrl = 'https://privseai.com';
  final http.Client _client = http.Client();

  String get baseUrl => _baseUrl;
  set baseUrl(String url) => _baseUrl = url;

  /// 사용자 DADA Point 잔액 및 랭킹 조회
  Future<PointBalance> getBalance(String userId) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/leaderboard/my-rank?user_id=$userId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PointBalance(
          points: data['points'] as int? ?? 0,
          rank: data['rank'] as int?,
          userId: data['user_id'] as String? ?? userId,
        );
      }
    } catch (e) {
      debugPrint('[Point] getBalance error: $e');
    }
    return PointBalance(points: 0, userId: userId);
  }

  /// 충전 내역 조회 (특정 사용자)
  Future<List<Map<String, dynamic>>> getMyCharges(String userId, {int limit = 20}) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/admin/point/history?user_id=$userId&limit=$limit'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
    } catch (e) {
      debugPrint('[Point] getMyCharges error: $e');
    }
    return [];
  }

  void dispose() {
    _client.close();
  }
}

class PointBalance {
  final int points;
  final int? rank;
  final String userId;

  PointBalance({
    required this.points,
    this.rank,
    required this.userId,
  });
}
