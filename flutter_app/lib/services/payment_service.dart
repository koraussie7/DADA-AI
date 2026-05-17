import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

class PaymentService {
  static final PaymentService _instance = PaymentService._();
  factory PaymentService() => _instance;
  PaymentService._();

  // Configurable base URL — defaults to the DADA-AI server
  String _baseUrl = 'https://privseai.com';
  final http.Client _client = http.Client();

  String get baseUrl => _baseUrl;
  set baseUrl(String url) => _baseUrl = url;

  /// Stripe 결제 세션 생성 → DADA Point 충전
  Future<ChargeResult> chargeDadaPoint({
    required int amount,
    String? userId,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/point/charge'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amount': amount,
              'payment_method': 'stripe',
              if (userId != null) 'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChargeResult(
          success: true,
          checkoutUrl: data['checkout_url'] as String?,
          sessionId: data['session_id'] as String?,
          chargeId: data['charge_id'] as String?,
        );
      }
      return ChargeResult(
        success: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('[Payment] Error: $e');
      return ChargeResult(success: false, error: e.toString());
    }
  }

  /// 충전 요청 상태 조회
  Future<Map<String, dynamic>?> getChargeStatus(String chargeId) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/point/charge/$chargeId'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['charge'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Payment] getChargeStatus error: $e');
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}

class ChargeResult {
  final bool success;
  final String? checkoutUrl;
  final String? sessionId;
  final String? chargeId;
  final String error;

  ChargeResult({
    required this.success,
    this.checkoutUrl,
    this.sessionId,
    this.chargeId,
    this.error = '',
  });

  @override
  String toString() {
    if (success) return 'ChargeResult(success, url=$checkoutUrl, chargeId=$chargeId)';
    return 'ChargeResult(failure, error=$error)';
  }
}
