import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';

class PointChargeScreen extends StatefulWidget {
  const PointChargeScreen({super.key});

  @override
  State<PointChargeScreen> createState() => _PointChargeScreenState();
}

class _PointChargeScreenState extends State<PointChargeScreen> {
  final List<_PointPackage> _packages = [
    _PointPackage(1000, "₩1,000"),
    _PointPackage(3000, "₩3,000"),
    _PointPackage(5000, "₩5,000"),
    _PointPackage(10000, "₩10,000"),
    _PointPackage(30000, "₩30,000"),
    _PointPackage(50000, "₩50,000"),
  ];
  int _selectedAmount = 3000;
  bool _isLoading = false;
  String? _error;

  String? _userId; // Set this from auth context

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DADA Point 충전"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0F0F1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(Icons.stars, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    "DADA Point를 충전하고\n프리미엄 기능을 이용하세요",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Package selection
            const Text(
              "충전 금액 선택",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "1 DADA Point = 1원",
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),

            ..._packages.map((pkg) {
              final isSelected = _selectedAmount == pkg.amount;
              return Card(
                color: isSelected
                    ? const Color(0xFF6B46C1).withValues(alpha: 0.25)
                    : const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF9F7AEA)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: Text(
                    "${pkg.amount.toStringAsFixed(0)} DADA Point",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    pkg.priceLabel,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF9F7AEA)
                          : Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF9F7AEA))
                      : const Icon(Icons.circle_outlined,
                          color: Colors.white24),
                  onTap: () => setState(() => _selectedAmount = pkg.amount),
                ),
              );
            }),

            const SizedBox(height: 32),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),

            // Charge button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startCharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B46C1),
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        "$_selectedAmount DADA Point 충전하기",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "📋 안내사항",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "• 결제는 Stripe를 통해 안전하게 처리됩니다.\n"
                    "• 충전 요청 후 관리자 승인 시 포인트가 지급됩니다.\n"
                    "• 승인까지 최대 24시간 소요될 수 있습니다.\n"
                    "• 충전 내역은 마이페이지에서 확인 가능합니다.",
                    style: TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCharge() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await PaymentService().chargeDadaPoint(
      amount: _selectedAmount,
      userId: _userId,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success && result.checkoutUrl != null) {
      // Launch Stripe Checkout
      final uri = Uri.parse(result.checkoutUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _error = "Stripe 결제 페이지를 열 수 없습니다.");
      }
    } else {
      setState(() => _error = result.error.isNotEmpty
          ? result.error
          : "충전 요청 중 오류가 발생했습니다.");
    }
  }
}

class _PointPackage {
  final int amount;
  final String priceLabel;
  const _PointPackage(this.amount, this.priceLabel);
}
