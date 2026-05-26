import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class RewardService {
  final String _baseUrl = AppConstants.apiBaseUrl;
  final http.Client _client;

  RewardService() : _client = http.Client();

  Future<RewardResult> rewardForWatch({
    required String userAddress,
    required String actionId,
    required int seconds,
  }) async {
    return _reward(userAddress, 'watch', actionId, seconds);
  }

  Future<RewardResult> rewardForAIChat({
    required String userAddress,
    required String actionId,
    required int seconds,
  }) async {
    return _reward(userAddress, 'ai', actionId, seconds);
  }

  Future<RewardResult> rewardForRelay({
    required String userAddress,
    required String actionId,
    required int seconds,
  }) async {
    return _reward(userAddress, 'relay', actionId, seconds);
  }

  Future<RewardResult> _reward(
    String userAddress,
    String action,
    String actionId,
    int seconds,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/blockchain/reward'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_address': userAddress,
              'action': action,
              'action_id': actionId,
              'seconds': seconds,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RewardResult(
          success: data['success'] == true,
          pointsEarned: data['points_earned'] as int? ?? 0,
          txId: data['tx_id'] as String? ?? '',
          action: action,
          error: data['error'] as String? ?? '',
        );
      }
      return RewardResult(success: false, pointsEarned: 0, txId: '', action: action, error: 'HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[Reward] Error: $e');
      return RewardResult(success: false, pointsEarned: 0, txId: '', action: action, error: e.toString());
    }
  }

  void dispose() {
    _client.close();
  }
}

class RewardResult {
  final bool success;
  final int pointsEarned;
  final String txId;
  final String action;
  final String error;

  RewardResult({
    required this.success,
    required this.pointsEarned,
    required this.txId,
    required this.action,
    this.error = '',
  });
}
