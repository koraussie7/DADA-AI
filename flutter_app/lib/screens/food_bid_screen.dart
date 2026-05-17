// lib/screens/food_bid_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../services/food_delivery_service.dart';
import '../widgets/shimmer_loading.dart';
import 'food_confirm_screen.dart';

class FoodBidScreen extends StatefulWidget {
  final String requestId;
  const FoodBidScreen({super.key, required this.requestId});

  @override
  State<FoodBidScreen> createState() => _FoodBidScreenState();
}

class _FoodBidScreenState extends State<FoodBidScreen> {
  String? _aiRecommendation;
  bool _loadingRecommendation = true;

  @override
  void initState() {
    super.initState();
    _loadAIRecommendation();
  }

  void _loadAIRecommendation() {
    final service = context.read<FoodDeliveryService>();
    // hermesRecommendation() is sync but may be empty if no bids yet
    final rec = service.hermesRecommendation();
    if (mounted) {
      setState(() {
        _aiRecommendation = rec;
        _loadingRecommendation = false;
      });
    }
  }

  double? _lowestPrice(List<FoodBid> bids) {
    if (bids.isEmpty) return null;
    return bids.map((b) => b.price).reduce((a, b) => a < b ? a : b);
  }

  Future<void> _selectBid(FoodBid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: const Text(
          'Select this restaurant?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bid.restaurantName,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '€${bid.price.toStringAsFixed(2)} · ${bid.estimatedMinutes} min',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
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
                    color: AppColors.textMuted,
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final service = context.read<FoodDeliveryService>();
      final ok = await service.selectBid(bid.id);
      if (ok && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FoodConfirmScreen(
              restaurantName: bid.restaurantName,
              price: bid.price,
              estimatedMinutes: bid.estimatedMinutes,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to select bid. It may have been taken.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FoodDeliveryService>();
    final bids = service.bids;
    final remainingSeconds = service.remainingSeconds;
    final isExpired = remainingSeconds <= 0 && bids.isEmpty;
    // If we have bids and timer expired, still show bids
    final showExpired = remainingSeconds <= 0 && bids.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Live Bidding'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Countdown Banner ──
          _buildCountdownBanner(remainingSeconds, showExpired, bids, service),

          // ── AI Recommendation ──
          if (_loadingRecommendation)
            _buildAIRecommendationShimmer()
          else if (_aiRecommendation != null && _aiRecommendation!.isNotEmpty && bids.isNotEmpty)
            _buildAIRecommendationBanner(),

          // ── Bids List / Empty State ──
          Expanded(
            child: showExpired
                ? _buildExpiredState()
                : bids.isEmpty
                    ? _buildEmptyState()
                    : _buildBidsList(bids, service),
          ),
        ],
      ),
    );
  }

  // ── Countdown Banner ──
  Widget _buildCountdownBanner(
    int remainingSeconds,
    bool isExpired,
    List<FoodBid> bids,
    FoodDeliveryService service,
  ) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeStr = isExpired || remainingSeconds <= 0
        ? (bids.isEmpty ? 'Expired' : '00:00')
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final lowest = _lowestPrice(bids);
    final lowestStr = lowest != null ? '€${lowest.toStringAsFixed(2)}' : '—';

    final reallyExpired = remainingSeconds <= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: reallyExpired
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: reallyExpired
                ? AppColors.error.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Timer ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    reallyExpired ? Icons.timer_off : Icons.timer,
                    size: 18,
                    color: reallyExpired ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: reallyExpired ? AppColors.error : Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${bids.length} bid${bids.length == 1 ? '' : 's'} received',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          // ── Lowest Price ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Lowest price',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                lowestStr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: lowest != null ? Colors.greenAccent : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI Recommendation Shimmer (while loading) ──
  Widget _buildAIRecommendationShimmer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
          SizedBox(width: 10),
          Expanded(child: ShimmerLoading(height: 14, borderRadius: 4)),
        ],
      ),
    );
  }

  // ── AI Recommendation Banner ──
  Widget _buildAIRecommendationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Recommendation',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _aiRecommendation!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State (Waiting for bids) ──
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPulseDots(),
            const SizedBox(height: 24),
            const ShimmerLoading(height: 100, borderRadius: 16),
            const SizedBox(height: 10),
            const ShimmerLoading(height: 100, borderRadius: 16),
            const SizedBox(height: 10),
            const ShimmerLoading(height: 100, borderRadius: 16),
            const SizedBox(height: 20),
            const Text(
              'Waiting for bids...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Restaurants are reviewing your order',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pulseDot(0),
        const SizedBox(width: 8),
        _pulseDot(0.3),
        const SizedBox(width: 8),
        _pulseDot(0.6),
      ],
    );
  }

  Widget _pulseDot(double delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {},
    );
  }

  // ── Expired State ──
  Widget _buildExpiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_off,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bidding Ended',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unfortunately, no restaurant placed a bid within the time limit. Please try again with a higher budget or different items.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Back to Order',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bids List ──
  Widget _buildBidsList(List<FoodBid> bids, FoodDeliveryService service) {
    final lowest = _lowestPrice(bids);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bids.length,
      itemBuilder: (_, i) => _FoodBidCard(
        bid: bids[i],
        isLowest: lowest != null && bids[i].price == lowest,
        onSelect: () => _selectBid(bids[i]),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  Food Bid Card
// ═══════════════════════════════════════════

class _FoodBidCard extends StatelessWidget {
  final FoodBid bid;
  final bool isLowest;
  final VoidCallback onSelect;

  const _FoodBidCard({
    required this.bid,
    required this.isLowest,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLowest
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Name + Best Badge ──
          Row(
            children: [
              // Restaurant icon placeholder
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bid.restaurantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isLowest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.withValues(alpha: 0.3),
                        Colors.greenAccent.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'BEST',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Rating Stars ──
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < bid.rating.round() ? Icons.star : Icons.star_border,
                  size: 16,
                  color: i < bid.rating.round() ? Colors.amber : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                bid.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${bid.estimatedMinutes} min',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Message ──
          if (bid.message.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Text(
                '"${bid.message}"',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Price + Select Button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total price',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '€${bid.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Select',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
