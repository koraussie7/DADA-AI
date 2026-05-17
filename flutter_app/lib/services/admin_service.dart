import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminService {
  static final AdminService _instance = AdminService._();
  factory AdminService() => _instance;
  AdminService._();

  String _baseUrl = 'https://privseai.com';
  final http.Client _client = http.Client();

  String get baseUrl => _baseUrl;
  set baseUrl(String url) => _baseUrl = url;

  /// 대기 중인 DADA Point 충전 요청 목록
  Future<List<Map<String, dynamic>>> getPendingPointCharges() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/admin/point/pending'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['charges'] ?? []);
      }
    } catch (e) {
      debugPrint('[Admin] getPendingPointCharges error: $e');
    }
    return [];
  }

  /// 충전 요청 승인 또는 거부
  Future<Map<String, dynamic>> approvePointCharge({
    required String chargeId,
    required String action, // "approve" or "reject"
    String? reason,
    String? adminId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/admin/point/approve').replace(
        queryParameters: adminId != null ? {'admin_id': adminId} : null,
      );
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'charge_id': chargeId,
              'action': action,
              if (reason != null) 'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[Admin] approvePointCharge error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// 충전 내역 전체 조회
  Future<List<Map<String, dynamic>>> getChargeHistory({
    String? userId,
    int limit = 50,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (userId != null) params['user_id'] = userId;

      final uri = Uri.parse('$_baseUrl/admin/point/history').replace(queryParameters: params);
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
    } catch (e) {
      debugPrint('[Admin] getChargeHistory error: $e');
    }
    return [];
  }

  void dispose() {
    _client.close();
  }
}
