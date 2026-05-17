// lib/screens/food_confirm_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../services/food_delivery_service.dart';

class FoodConfirmScreen extends StatefulWidget {
  final String restaurantName;
  final double price;
  final int estimatedMinutes;

  const FoodConfirmScreen({
    super.key,
    required this.restaurantName,
    required this.price,
    required this.estimatedMinutes,
  });

  @override
  State<FoodConfirmScreen> createState() => _FoodConfirmScreenState();
}

class _FoodConfirmScreenState extends State<FoodConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _animController.forward();

    // Reset the service state after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<FoodDeliveryService>().reset();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate a realistic arrival time
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: widget.estimatedMinutes));
    final timeStr = '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';

    // Access the last address from the service
    final service = context.watch<FoodDeliveryService>();
    final address = service.lastAddress ?? 'Your delivery address';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        centerTitle: true,
        leading: const SizedBox(), // hide back button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Success Animation ──
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF22C55E),
                        Color(0xFF16A34A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Title ──
              FadeTransition(
                opacity: _fadeAnim,
                child: const Text(
                  'Order Confirmed!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeTransition(
                opacity: _fadeAnim,
                child: Text(
                  'Your food is on its way',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Order Details Card ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      // ── Restaurant ──
                      _detailRow(
                        icon: Icons.restaurant,
                        label: 'Restaurant',
                        value: widget.restaurantName,
                        valueColor: AppColors.primary,
                      ),

                      const Divider(
                        color: Colors.white10,
                        height: 24,
                      ),

                      // ── Price ──
                      _detailRow(
                        icon: Icons.payments_outlined,
                        label: 'Total Price',
                        value: '€${widget.price.toStringAsFixed(2)}',
                        valueColor: Colors.greenAccent,
                      ),

                      const Divider(
                        color: Colors.white10,
                        height: 24,
                      ),

                      // ── Estimated Delivery ──
                      _detailRow(
                        icon: Icons.access_time,
                        label: 'Estimated Delivery',
                        value: '$timeStr (~${widget.estimatedMinutes} min)',
                        valueColor: Colors.white,
                      ),

                      const Divider(
                        color: Colors.white10,
                        height: 24,
                      ),

                      // ── Delivery Address ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.info,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivery Address',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  address,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Status Tracker ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      _buildStatusStep('Order Placed', true),
                      _buildStatusConnector(true),
                      _buildStatusStep('Preparing', true),
                      _buildStatusConnector(true),
                      _buildStatusStep('On the Way', false),
                      _buildStatusConnector(false),
                      _buildStatusStep('Delivered', false),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Back to Home Button ──
              FadeTransition(
                opacity: _fadeAnim,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home_rounded, size: 20),
                    label: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: valueColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusStep(String label, bool isCompleted) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF22C55E) : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF22C55E)
                  : Colors.white.withValues(alpha: 0.15),
              width: 2,
            ),
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : const SizedBox(),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            color: isCompleted ? Colors.white : AppColors.textMuted,
            fontSize: 15,
            fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusConnector(bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Container(
        width: 4,
        height: 28,
        decoration: BoxDecoration(
          color: isCompleted
              ? const Color(0xFF22C55E).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
