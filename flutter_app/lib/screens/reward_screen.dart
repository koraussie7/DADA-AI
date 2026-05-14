import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'live_commerce_screen.dart';

class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("DADA-AI", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 10),
                SizedBox(width: 6),
                Text("P2P 연결됨", style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // DADA Point Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA), Color(0xFFED64A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                children: [
                  const Text("보유 DADA Point", style: TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 8),
                  const Text("24,850 P", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPointChip("+2,400 오늘"),
                      const SizedBox(width: 12),
                      _buildPointChip("이번 주 11.2K"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // News Feed + Weather Widget
            const Text("What's New", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Container(
              decoration: AppTheme.strongGlass,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weather Widget
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 32),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("서울", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          Text("맑음 • 21°C", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text("미세먼지 좋음", style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                          Text("습도 45%", style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 32, color: Colors.white24),

                  // News / Announcement Feed
                  const Text("DADA-AI 소식", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  _buildNewsItem(
                    emoji: "\u{1F680}",
                    title: "Liberty Reach P2P v0.4 업데이트",
                    subtitle: "오늘부터 완전 탈중앙 Live Commerce 지원",
                    time: "방금",
                  ),
                  const SizedBox(height: 12),

                  _buildNewsItem(
                    emoji: "\u{1F381}",
                    title: "DADA Point 2배 이벤트",
                    subtitle: "Live Commerce 참여 시 포인트 2배 지급",
                    time: "3시간 전",
                  ),
                  const SizedBox(height: 12),

                  _buildNewsItem(
                    emoji: "\u{1F916}",
                    title: "Hermes AI 업데이트",
                    subtitle: "상품 추천 정확도 94% 달성",
                    time: "어제",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Live Video Commerce Hero
            const Text("AI Live Commerce", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 240,
              decoration: AppTheme.strongGlass.copyWith(
                image: const DecorationImage(
                  image: NetworkImage("https://picsum.photos/id/1015/800/450"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: Colors.white),
                          SizedBox(width: 6),
                          Text("LIVE", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.glassDecoration,
                      child: const Row(
                        children: [
                          Text("\u{1F916}", style: TextStyle(fontSize: 24)),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hermes AI", style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
                              Text("추천 중", style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _buildProductTag("\u{1F3A7} 이어폰 45K"),
                        const SizedBox(width: 8),
                        _buildProductTag("\u{1F45F} 운동화 89K"),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.extended(
                      onPressed: () => _startLiveCommerce(context),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      label: const Text("GO LIVE", style: TextStyle(fontWeight: FontWeight.bold)),
                      icon: const Icon(Icons.play_arrow),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Trending Commerce
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("\u{1F525} Trending Commerce", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text("전체보기")),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 210,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _CommerceCard(imageId: "201", title: "#커플이어폰", viewers: "12.4K", reward: "+450P"),
                  _CommerceCard(imageId: "237", title: "#고양이 ASMR", viewers: "8.2K", reward: "+800P", isLive: true),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Reward Menu Grid
            const Text("리워드 메뉴", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildMenuCard("\u{1F4F9} AI Live", "300~2,000P", "Hermes 자동 판매"),
                _buildMenuCard("\u{1F465} 친구 초대", "500P / 명", "최대 20명"),
                _buildMenuCard("\u{1F3AF} 미션", "최대 5,000P", "매일 도전"),
                _buildMenuCard("\u{1F6D2} 포인트 쇼핑", "상품 교환", ""),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPointChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildProductTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildMenuCard(String title, String points, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(points, style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildNewsItem({
    required String emoji,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
        Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _startLiveCommerce(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveCommerceScreen()),
    );
  }
}

class _CommerceCard extends StatelessWidget {
  final String imageId;
  final String title;
  final String viewers;
  final String reward;
  final bool isLive;

  const _CommerceCard({
    required this.imageId, required this.title, required this.viewers,
    required this.reward, this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Image.network(
              "https://picsum.photos/id/$imageId/400/220",
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("$viewers ${isLive ? '• LIVE' : '시청'}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(reward, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
