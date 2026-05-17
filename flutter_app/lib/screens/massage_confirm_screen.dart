// lib/screens/massage_confirm_screen.dart
import 'package:flutter/material.dart';
import '../core/design_system/app_colors.dart';

class MassageConfirmScreen extends StatefulWidget {
  final String therapistName;
  final double price;
  final int estimatedMinutes;
  final List<String> specialties;

  const MassageConfirmScreen({
    super.key,
    required this.therapistName,
    required this.price,
    required this.estimatedMinutes,
    this.specialties = const [],
  });

  @override
  State<MassageConfirmScreen> createState() => _MassageConfirmScreenState();
}

class _MassageConfirmScreenState extends State<MassageConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _animController.forward();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffoldBg,
    appBar: AppBar(title: const Text('Booking Confirmed! 🎉'), centerTitle: true, automaticallyImplyLeading: false),
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(children: [
        ScaleTransition(scale: _scaleAnim, child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF22C55E).withValues(alpha: 0.12), border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3), width: 2)),
          child: const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 60),
        )),
        const SizedBox(height: 24),
        FadeTransition(opacity: _fadeAnim, child: Column(children: [
          const Text('Massage Booked!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${widget.therapistName} is on the way', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ])),
        const SizedBox(height: 32),
        FadeTransition(opacity: _fadeAnim, child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
          child: Column(children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.spa, color: AppColors.primary, size: 32)),
            const SizedBox(height: 12),
            Text(widget.therapistName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            if (widget.specialties.isNotEmpty) ...[const SizedBox(height: 4), Text(widget.specialties.join(' · '), style: const TextStyle(color: AppColors.textMuted, fontSize: 14))],
            const Divider(height: 30, color: Colors.white12),
            _detailRow(Icons.access_time, 'ETA', '${widget.estimatedMinutes} min'),
            const SizedBox(height: 12),
            _detailRow(Icons.attach_money, 'Price', '\$${widget.price.toStringAsFixed(2)}'),
          ]),
        )),
        const SizedBox(height: 40),
        FadeTransition(opacity: _fadeAnim, child: SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('Back to Home', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        )),
      ]),
    ),
  );

  Widget _detailRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 18, color: AppColors.textMuted),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
    const Spacer(),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
  ]);
}
