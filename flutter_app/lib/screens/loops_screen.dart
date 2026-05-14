import 'package:flutter/material.dart';
import '../services/loops_service.dart';
import '../widgets/p2p_video_player.dart';
import 'loops_player_screen.dart';

class LoopsScreen extends StatefulWidget {
  const LoopsScreen({super.key});

  @override
  State<LoopsScreen> createState() => _LoopsScreenState();
}

class _LoopsScreenState extends State<LoopsScreen> {
  final LoopsService _service = LoopsService();
  List<LoopVideo> _videos = [];
  bool _loading = true;

  static const _fallbackVideos = [
    _FallbackVideo(
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      title: 'Bigger Blazes',
      uploader: 'Google Samples',
    ),
    _FallbackVideo(
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      title: 'Bigger Escapes',
      uploader: 'Google Samples',
    ),
    _FallbackVideo(
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      title: 'Bigger Fun',
      uploader: 'Google Samples',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final feed = await _service.getFeed();
    if (mounted) {
      setState(() {
        _videos = feed;
        _loading = false;
      });
    }
  }

  void _openPlayer(int index, {LoopVideo? video}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoopsPlayerScreen(videoIndex: index, video: video),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _LoopsAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final useFallback = _videos.isEmpty;
    final items = useFallback ? _fallbackVideos.map((f) => (
      videoUrl: f.url,
      title: f.title,
      creator: f.uploader,
      video: null as LoopVideo?,
    )).toList() : _videos.map((v) => (
      videoUrl: v.videoUrl ?? v.thumbnailUrl ?? '',
      title: v.title,
      creator: v.creator,
      video: v,
    )).toList();

    return Scaffold(
      appBar: const _LoopsAppBar(),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => _openPlayer(i, video: item.video),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: P2PVideoPlayer(
                videoUrl: item.videoUrl,
                title: item.title,
                uploader: item.creator,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoopsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _LoopsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 22),
          SizedBox(width: 8),
          Text('Loops'),
        ],
      ),
    );
  }
}

class _FallbackVideo {
  final String url;
  final String title;
  final String uploader;

  const _FallbackVideo({
    required this.url,
    required this.title,
    required this.uploader,
  });
}
