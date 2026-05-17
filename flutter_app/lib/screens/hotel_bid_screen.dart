import 'package:flutter/material.dart'; import 'package:provider/provider.dart'; import '../services/hotel_service.dart'; import '../widgets/shimmer_loading.dart';

class HotelBidScreen extends StatefulWidget {
  final String requestId;
  const HotelBidScreen({super.key, required this.requestId});

  @override
  State<HotelBidScreen> createState() => _HotelBidScreenState();
}

class _HotelBidScreenState extends State<HotelBidScreen> {
  String? _aiRecommendation;
  bool _loadingAI = false;

  @override
  void initState() {
    super.initState();
    _loadAI();
  }

  Future<void> _loadAI() async {
    setState(() => _loadingAI = true);
    final service = context.read<HotelService>();
    final rec = await service.hermesRecommendation();
    if (mounted) setState(() { _aiRecommendation = rec; _loadingAI = false; });
  }

  Future<void> _selectBid(HotelBid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select this hotel?'),
        content: Text('${bid.hotelName}\n${bid.price}원\n\n${bid.message}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await context.read<HotelService>().selectBid(bid.id);
      if (ok && mounted) {
        Navigator.pop(context); // Return to hotels list after confirmation
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<HotelService>();
    final bids = service.bids;
    final isExpired = service.remainingSeconds <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Bidding')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⏱ ${isExpired ? "Expired" : "${(service.remainingSeconds ~/ 60).toString().padLeft(2, "0")}:${(service.remainingSeconds % 60).toString().padLeft(2, "0")}"}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${bids.length} bids received', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Lowest Price', style: TextStyle(fontSize: 12)),
                    Text('${service.lowestPrice}원', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
          if (_aiRecommendation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('🤖 $_aiRecommendation', style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          Expanded(
            child: bids.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShimmerLoading(height: 120, borderRadius: 16),
                        SizedBox(height: 8),
                        ShimmerLoading(height: 120, borderRadius: 16),
                        SizedBox(height: 16),
                        Text('Waiting for hotel bids...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: bids.length,
                    itemBuilder: (_, i) => _BidCard(
                      bid: bids[i],
                      isLowest: bids[i].price == service.lowestPrice,
                      onSelect: () => _selectBid(bids[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BidCard extends StatelessWidget {
  final HotelBid bid;
  final bool isLowest;
  final VoidCallback onSelect;

  const _BidCard({required this.bid, required this.isLowest, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(bid.hotelName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (isLowest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                    child: const Text('BEST', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                ...List.generate(5, (i) => Icon(Icons.star, size: 14, color: i < bid.rating.round() ? Colors.amber : Colors.grey[300])),
                const SizedBox(width: 8),
                Text(bid.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(bid.message, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4, runSpacing: 4,
              children: bid.amenities.map((a) => Chip(label: Text(a, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${bid.price}원', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                FilledButton(onPressed: onSelect, child: const Text('Select')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
