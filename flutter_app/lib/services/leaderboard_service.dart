import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class LeaderboardService {
  final String _baseUrl = AppConstants.apiBaseUrl;
  final http.Client _client;

  LeaderboardService() : _client = http.Client();

  Future<List<RankEntry>> getLeaderboard(String period, {int limit = 50}) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/leaderboard/$period?limit=$limit'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List? ?? [];
        return list.map((e) => RankEntry(
          rank: e['rank'] as int,
          userId: e['user_id'] as String? ?? '',
          displayName: e['display_name'] as String? ?? 'Unknown',
          points: e['points'] as int? ?? 0,
          badge: e['badge'] as String? ?? 'Newbie',
        )).toList();
      }
    } catch (e) {
      debugPrint('[Leaderboard] Error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getMyRank(String userId) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/leaderboard/my-rank?user_id=${Uri.encodeComponent(userId)}'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Leaderboard] My rank error: $e');
    }
    return {'rank': null, 'points': 0, 'user_id': userId};
  }

  Future<LeaderboardStats?> getStats() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/leaderboard/stats'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return LeaderboardStats.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[Leaderboard] Stats error: $e');
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}

class LeaderboardStats {
  final int onchainBalance;
  final String address;
  final int totalUsers;
  final int totalPointsDistributed;
  final int totalTransactions;
  final int dadaSupply;
  final int remaining;

  LeaderboardStats({
    required this.onchainBalance,
    required this.address,
    required this.totalUsers,
    required this.totalPointsDistributed,
    required this.totalTransactions,
    required this.dadaSupply,
    required this.remaining,
  });

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) {
    final onchain = json['onchain'] as Map<String, dynamic>? ?? {};
    final offchain = json['offchain'] as Map<String, dynamic>? ?? {};
    return LeaderboardStats(
      onchainBalance: onchain['dada_point_balance'] as int? ?? 0,
      address: onchain['address'] as String? ?? '',
      totalUsers: offchain['total_users'] as int? ?? 0,
      totalPointsDistributed: offchain['total_points_distributed'] as int? ?? 0,
      totalTransactions: offchain['total_transactions'] as int? ?? 0,
      dadaSupply: json['dada_supply'] as int? ?? 1000000,
      remaining: json['remaining'] as int? ?? 0,
    );
  }

  double get percentDistributed =>
      dadaSupply > 0 ? (totalPointsDistributed / dadaSupply) * 100 : 0;
}

class RankEntry {
  final int rank;
  final String userId;
  final String displayName;
  final int points;
  final String badge;

  RankEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.points,
    required this.badge,
  });

  bool get isTop3 => rank <= 3;
}
