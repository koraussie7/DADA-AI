import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LoopVideo {
  final String id;
  final String title;
  final String description;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int viewCount;
  final int rewardPoints;
  final String creator;

  LoopVideo({
    required this.id,
    required this.title,
    this.description = '',
    this.videoUrl,
    this.thumbnailUrl,
    this.viewCount = 0,
    this.rewardPoints = 0,
    this.creator = 'Liberty Reach',
  });

  factory LoopVideo.fromJson(Map<String, dynamic> json) => LoopVideo(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled',
        description: json['description'] as String? ?? '',
        videoUrl: json['video_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        viewCount: json['view_count'] as int? ?? 0,
        rewardPoints: json['reward_points'] as int? ?? 0,
        creator: json['creator'] as String? ?? 'Unknown',
      );

  factory LoopVideo.demo(int index) => LoopVideo(
        id: 'loop_$index',
        title: 'Loop ${index + 1}',
        description: 'Liberty Reach AI P2P Messenger',
        viewCount: 120 + index * 15,
        rewardPoints: (index + 1) * 15,
        creator: 'Creator ${index + 1}',
      );
}

class LoopsService extends ChangeNotifier {
  final String _baseUrl = '';
  final http.Client _client;

  LoopsService() : _client = http.Client();

  Future<List<LoopVideo>> getFeed() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/loops/feed'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List? ?? [];
        if (list.isNotEmpty) {
          return list.map((e) => LoopVideo.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[Loops] Feed error: $e');
    }
    return [];
  }

  Future<LoopVideo?> getVideo(String videoId) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/loops/video/$videoId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LoopVideo.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[Loops] Video error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> uploadVideo(String base64Video, String caption) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/loops/upload'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'video': base64Video, 'caption': caption}),
          )
          .timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Loops] Upload error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
