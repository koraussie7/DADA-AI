import 'package:flutter/material.dart';
import 'data.dart';

class LoopThumbnailCard extends StatelessWidget {
  final LoopVideo loop;

  const LoopThumbnailCard({super.key, required this.loop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.primaries[int.parse(loop.id.split('_').last) % Colors.primaries.length].withOpacity(0.4),
            Colors.primaries[(int.parse(loop.id.split('_').last) + 3) % Colors.primaries.length].withOpacity(0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white70, size: 32),
          const SizedBox(height: 6),
          Text(loop.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('${loop.viewCount}회', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }
}
