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

  factory LoopVideo.demo(int index) => LoopVideo(
        id: 'loop_$index',
        title: 'Loop ${index + 1}',
        description: 'Liberty Reach AI P2P Messenger',
        viewCount: 120 + index * 15,
        rewardPoints: (index + 1) * 15,
        creator: 'Creator ${index + 1}',
      );
}
