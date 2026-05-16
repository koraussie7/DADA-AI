class DADABalance {
  final int balance;
  final String address;
  final String? error;

  DADABalance({required this.balance, required this.address, this.error});

  factory DADABalance.fromJson(Map<String, dynamic> json) => DADABalance(
        balance: json['balance'] as int? ?? 0,
        address: json['address'] as String? ?? '',
        error: json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'balance': balance,
        'address': address,
        if (error != null) 'error': error,
      };
}

class RewardResult {
  final int pointsEarned;
  final String txId;
  final String action;
  final bool success;
  final String error;

  RewardResult({
    required this.pointsEarned,
    required this.txId,
    required this.action,
    required this.success,
    required this.error,
  });

  factory RewardResult.fromJson(Map<String, dynamic> json) => RewardResult(
        pointsEarned: json['points_earned'] as int? ?? 0,
        txId: json['tx_id'] as String? ?? '',
        action: json['action'] as String? ?? '',
        success: json['success'] as bool? ?? false,
        error: json['error'] as String? ?? '',
      );

  factory RewardResult.empty() => RewardResult(
        pointsEarned: 0,
        txId: '',
        action: '',
        success: false,
        error: '',
      );
}

enum RewardActionType {
  watchVideo,
  aiChat,
  p2pRelay;

  String get label {
    switch (this) {
      case RewardActionType.watchVideo:
        return 'Watch Video';
      case RewardActionType.aiChat:
        return 'AI Chat';
      case RewardActionType.p2pRelay:
        return 'P2P Relay';
    }
  }

  String get apiName {
    switch (this) {
      case RewardActionType.watchVideo:
        return 'watch';
      case RewardActionType.aiChat:
        return 'ai';
      case RewardActionType.p2pRelay:
        return 'relay';
    }
  }

  int get minSeconds {
    switch (this) {
      case RewardActionType.watchVideo:
        return 15;
      case RewardActionType.aiChat:
        return 30;
      case RewardActionType.p2pRelay:
        return 60;
    }
  }
}
