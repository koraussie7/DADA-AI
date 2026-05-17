// lib/screens/taxi_bid_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../services/taxi_service.dart';
import '../widgets/shimmer_loading.dart';
import 'taxi_confirm_screen.dart';

class TaxiBidScreen extends StatefulWidget {
  final String requestId;
  const TaxiBidScreen({super.key, required this.requestId});

  @override
  State<TaxiBidScreen> createState() => _TaxiBidScreenState();
}

class _TaxiBidScreenState extends State<TaxiBidScreen> {
  @override
  Widget build(BuildContext context) {
    final service = context.watch<TaxiService>();
    final isExpired = service.remainingSeconds <= 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('🚗 Waiting for Drivers'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Ride Info Banner ──
          _buildRideInfoBanner(service),

          // ── Countdown ──
          _buildCountdownBar(service, isExpired),

          // ── AI Recommendation ──
          if (service.bids.isNotEmpty)
            _buildAIRecommendation(service),

          // ── Bids List ──
          Expanded(
            child: isExpired
                ? _buildExpiredState()
                : service.bids.isEmpty
                    ? _buildWaitingState()
                    : _buildBidsList(service),
          ),
        ],
      ),
    );
  }

  Widget _buildRideInfoBanner(TaxiService service) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin, color: Color(0xFF22C55E), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service.pickupAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 7),
            child: SizedBox(
              height: 20,
              child: VerticalDivider(color: Colors.white12, thickness: 2),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service.dropoffAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                '${service.passengers} passenger${service.passengers == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.attach_money, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(
                'Max \$${service.maxBudget.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBar(TaxiService service, bool isExpired) {
    final progress = service.remainingSeconds / 300.0;
    final color = progress > 0.5
        ? const Color(0xFF22C55E)
        : progress > 0.2
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    final minutes = (service.remainingSeconds / 60).floor();
    final seconds = service.remainingSeconds % 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.timer_off : Icons.timer,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isExpired
                ? const Text(
                    'Bidding has ended',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  )
                : Text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining',
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
          if (!isExpired)
            Text(
              '${service.bids.length} bid${service.bids.length == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendation(TaxiService service) {
    final rec = service.hermesRecommendation();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rec,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ShimmerLoading(
            width: 120,
            height: 120,
            borderRadius: 60,
          ),
          const SizedBox(height: 24),
          const Text(
            'Waiting for drivers to bid...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Drivers near you are reviewing your request',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off, color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Bidding has ended',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              context.read<TaxiService>().reset();
              Navigator.pop(context);
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBidsList(TaxiService service) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: service.bids.length,
      itemBuilder: (context, index) {
        final bid = service.bids[index];
        return _BidCard(
          bid: bid,
          index: index + 1,
          onSelect: () => _selectBid(service, bid),
        );
      },
    );
  }

  Future<void> _selectBid(TaxiService service, TaxiBid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: const Text('Select this driver?',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bid.driverName,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${bid.price.toStringAsFixed(2)} · ${bid.estimatedMinutes} min',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (bid.carModel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${bid.carModel} · ${bid.carColor}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
            if (bid.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"${bid.message}"',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm Ride'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await service.selectBid(bid.id);
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TaxiConfirmScreen(
              driverName: bid.driverName,
              price: bid.price,
              estimatedMinutes: bid.estimatedMinutes,
              carModel: bid.carModel,
              carColor: bid.carColor,
            ),
          ),
        );
      }
    }
  }
}

class _BidCard extends StatelessWidget {
  final TaxiBid bid;
  final int index;
  final VoidCallback onSelect;

  const _BidCard({
    required this.bid,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Driver avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, color: AppColors.primary, size: 22),
                  if (bid.rating > 0)
                    Text(
                      '⭐${bid.rating.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Driver info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bid.driverName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (bid.carModel.isNotEmpty)
                    Text(
                      '${bid.carModel} · ${bid.carColor}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${bid.estimatedMinutes} min',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Price + Select
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${bid.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
