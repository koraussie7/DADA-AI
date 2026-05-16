import 'package:flutter/material.dart';
import 'data.dart';

class RewardBalanceCard extends StatelessWidget {
  final DADABalance balance;
  final bool isLoading;

  const RewardBalanceCard({
    super.key,
    required this.balance,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DADA Points', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (isLoading)
              const CircularProgressIndicator()
            else ...[
              Text(
                '${balance.balance}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (balance.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  balance.address,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (balance.error != null)
                Text(
                  balance.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class RewardHistoryTile extends StatelessWidget {
  final RewardResult reward;
  final bool isLast;

  const RewardHistoryTile({
    super.key,
    required this.reward,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        reward.success ? Icons.check_circle : Icons.error,
        color: reward.success ? Colors.green : theme.colorScheme.error,
      ),
      title: Text('+${reward.pointsEarned} DADA'),
      subtitle: Text(
        '${reward.action}${reward.txId.isNotEmpty ? ' • ${reward.txId.substring(0, 8)}...' : ''}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
