import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class LiveCommerceScreen extends StatelessWidget {
  const LiveCommerceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Background
          Image.network(
            "https://picsum.photos/id/1015/800/1200",
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 10),
                        SizedBox(width: 6),
                        Text("LIVE"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hermes AI Floating Panel
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassDecoration,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("\u{1F916} Hermes AI", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("실시간 상품 추천 중...", style: TextStyle(color: Colors.greenAccent)),
                ],
              ),
            ),
          ),

          // Bottom Product Bar
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.strongGlass,
              child: Column(
                children: [
                  const Text("지금 판매 중인 상품", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _productChip("\u{1F3A7} 이어폰", "45,000P"),
                      const SizedBox(width: 12),
                      _productChip("\u{1F45F} 운동화", "89,000P"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Buy & Chat Button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text("바로 구매하기", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text("Hermes와 채팅"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productChip(String name, String price) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(name),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
