import 'package:flutter/material.dart';
import '../services/loops_service.dart';
import '../services/hybrid_ai_service.dart';

class LoopsPlayerScreen extends StatefulWidget {
  final int videoIndex;
  final LoopVideo? video;

  const LoopsPlayerScreen({super.key, required this.videoIndex, this.video});

  @override
  State<LoopsPlayerScreen> createState() => _LoopsPlayerScreenState();
}

class _LoopsPlayerScreenState extends State<LoopsPlayerScreen> {
  final HybridAIService _ai = HybridAIService();
  int _likeCount = 0;
  bool _liked = false;
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.3), size: 80),
                  const SizedBox(height: 16),
                  Text(
                    v?.title ?? 'Loop ${widget.videoIndex + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    v?.description ?? (v != null ? '' : 'Video player ready'),
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 160,
            child: Column(
              children: [
                _ActionButton(
                  icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: _liked ? '$_likeCount' : '좋아요',
                  active: _liked,
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '댓글',
                  onTap: _showComments,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: _isAnalyzing ? Icons.hourglass_top : Icons.auto_awesome,
                  label: 'AI 분석',
                  onTap: _isAnalyzing ? null : _analyzeWithAI,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: '공유',
                  onTap: _shareVideo,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text('+${v?.rewardPoints ?? (widget.videoIndex + 1) * 15} DADA',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${v?.viewCount ?? 120 + widget.videoIndex * 15} views',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v?.title ?? 'Loop ${widget.videoIndex + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    v?.creator ?? 'Liberty Reach',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_liked ? '좋아요 +1 DADA' : '좋아요 취소'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                const Text('댓글', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
            const Divider(),
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person, size: 18)),
              title: Text('user_0x3a1', style: TextStyle(color: Colors.white70, fontSize: 14)),
              subtitle: Text('와 이거 진짜 대박이에요! 🔥', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person, size: 18)),
              title: Text('dada_fan', style: TextStyle(color: Colors.white70, fontSize: 14)),
              subtitle: Text('DADA Point 받고 보니 더 재밌네요 ㅎㅎ', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: '댓글 입력...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.cyanAccent, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeWithAI() async {
    setState(() => _isAnalyzing = true);
    final v = widget.video;
    final result = await _ai.process(
      'Analyze this short-form video:\nTitle: ${v?.title ?? "Loop ${widget.videoIndex + 1}"}\n'
      'Creator: ${v?.creator ?? "Liberty Reach"}\n'
      'Description: ${v?.description ?? ""}\n\n'
      'Provide: 1) Content summary 2) Target audience 3) Engagement potential',
    );
    setState(() => _isAnalyzing = false);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 20),
                const SizedBox(width: 8),
                const Text('AI 분석 결과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            SelectableText(result, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('P2P 네트워크로 공유 중...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.cyan,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? Colors.cyanAccent.withOpacity(0.25) : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.cyanAccent : Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: active ? Colors.cyanAccent : Colors.white.withOpacity(0.8),
            fontSize: 11,
          )),
        ],
      ),
    );
  }
}
