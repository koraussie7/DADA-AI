// lib/screens/massage_bid_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../services/massage_service.dart';
import '../widgets/shimmer_loading.dart';
import 'massage_confirm_screen.dart';

class MassageBidScreen extends StatefulWidget {
  final String requestId;
  const MassageBidScreen({super.key, required this.requestId});

  @override
  State<MassageBidScreen> createState() => _MassageBidScreenState();
}

class _MassageBidScreenState extends State<MassageBidScreen> {
  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MassageService>();
    final expired = svc.remainingSeconds <= 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('💆 Waiting for Therapists'), centerTitle: true),
      body: Column(children: [
        _buildInfoBanner(svc),
        _buildCountdown(svc, expired),
        if (svc.bids.isNotEmpty) _buildAIRecommendation(svc),
        Expanded(child: expired ? _buildExpired() : svc.bids.isEmpty ? _buildWaiting() : _buildBids(svc)),
      ]),
    );
  }

  Widget _buildInfoBanner(MassageService svc) => Container(
    width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.spa, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(svc.serviceType, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${svc.durationMinutes} min', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(svc.address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ]),
  );

  Widget _buildCountdown(MassageService svc, bool expired) {
    final p = svc.remainingSeconds / 300.0;
    final c = p > 0.5 ? const Color(0xFF22C55E) : p > 0.2 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final m = (svc.remainingSeconds / 60).floor();
    final s = svc.remainingSeconds % 60;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(expired ? Icons.timer_off : Icons.timer, color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(expired ? 'Bidding has ended' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} remaining', style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w600))),
        if (!expired) Text('${svc.bids.length} bid${svc.bids.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _buildAIRecommendation(MassageService svc) {
    final rec = svc.hermesRecommendation();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(rec, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
      ]),
    );
  }

  Widget _buildWaiting() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const ShimmerLoading(width: 120, height: 120, borderRadius: 60),
    const SizedBox(height: 24),
    const Text('Waiting for therapists to bid...', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
    const SizedBox(height: 8),
    Text('Therapists near you are reviewing your request', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
  ]));

  Widget _buildExpired() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.timer_off, color: AppColors.textMuted, size: 64),
    const SizedBox(height: 16),
    const Text('Bidding has ended', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
    const SizedBox(height: 8),
    TextButton(onPressed: () { context.read<MassageService>().reset(); Navigator.pop(context); }, child: const Text('Try again')),
  ]));

  Widget _buildBids(MassageService svc) => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: svc.bids.length,
    itemBuilder: (ctx, i) => _BidCard(bid: svc.bids[i], onSelect: () => _selectBid(svc, svc.bids[i])),
  );

  Future<void> _selectBid(MassageService svc, MassageBid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        title: const Text('Select this therapist?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bid.therapistName, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('\$${bid.price.toStringAsFixed(2)} · ${bid.estimatedMinutes} min', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          if (bid.message.isNotEmpty) ...[const SizedBox(height: 8), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)), child: Text('"${bid.message}"', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)))],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await svc.selectBid(bid.id);
      if (ok && mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MassageConfirmScreen(therapistName: bid.therapistName, price: bid.price, estimatedMinutes: bid.estimatedMinutes, specialties: bid.specialties)));
    }
  }
}

class _BidCard extends StatelessWidget {
  final MassageBid bid;
  final VoidCallback onSelect;
  const _BidCard({required this.bid, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.person, color: AppColors.primary, size: 22),
          if (bid.rating > 0) Text('⭐${bid.rating.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 8, fontWeight: FontWeight.w700)),
        ])),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(bid.therapistName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        if (bid.specialties.isNotEmpty) Text(bid.specialties.join(' · '), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Row(children: [const Icon(Icons.access_time, size: 12, color: AppColors.textMuted), const SizedBox(width: 4), Text('${bid.estimatedMinutes} min', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))]),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('\$${bid.price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SizedBox(height: 32, child: ElevatedButton(onPressed: onSelect, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0), child: const Text('Select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
      ]),
    ]),
  );
}
