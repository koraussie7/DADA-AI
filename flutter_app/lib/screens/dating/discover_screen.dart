import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/dating_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    final svc = context.read<DatingService>();
    if (svc.users.isEmpty && !svc.isLoading) {
      svc.loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DatingService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text(
          'SparkMatch',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            onPressed: () => Navigator.pushNamed(context, '/matches'),
          ),
          IconButton(
            icon: const Icon(Icons.explore, color: Colors.white70),
            onPressed: () => Navigator.pushNamed(context, '/explore'),
          ),
        ],
      ),
      body: svc.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : svc.users.isEmpty
              ? _buildEmpty(context)
              : _buildSwipeStack(context, svc, isDark),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 80, color: Colors.pinkAccent),
          const SizedBox(height: 20),
          const Text(
            'No more profiles',
            style: TextStyle(fontSize: 22, color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new people!',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: () => context.read<DatingService>().addMoreUsers(),
            icon: const Icon(Icons.refresh),
            label: const Text('Load More'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeStack(BuildContext context, DatingService svc, bool isDark) {
    final user = svc.users.first;

    return Stack(
      children: [
        // Profile card
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            child: _ProfileCard(user: user, isDark: isDark),
          ),
        ),
        // Action buttons
        Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: _ActionButtons(
            onDislike: () {
              context.read<DatingService>().dislike(user);
              HapticFeedback.lightImpact();
            },
            onSuperLike: () {
              context.read<DatingService>().superLike(user);
              HapticFeedback.heavyImpact();
              _showMatchDialog(context);
            },
            onLike: () {
              context.read<DatingService>().like(user);
              HapticFeedback.lightImpact();
            },
          ),
        ),
      ],
    );
  }

  void _showMatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 60, color: Colors.pinkAccent),
            SizedBox(height: 16),
            Text('Super Like!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 8),
            Text('You super liked this profile', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile user;
  final bool isDark;

  const _ProfileCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              Image.network(
                user.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[850],
                  child: const Center(
                    child: Icon(Icons.person, size: 80, color: Colors.grey),
                  ),
                ),
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              // Info
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${user.name}, ${user.age}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 2),
                        Text(
                          '${user.distance}km',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.bio,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: user.interests.take(3).map((i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.5)),
                          ),
                          child: Text(i, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onDislike;
  final VoidCallback onSuperLike;
  final VoidCallback onLike;

  const _ActionButtons({
    required this.onDislike,
    required this.onSuperLike,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Dislike (X)
        _ActionButton(
          icon: Icons.close_rounded,
          color: Colors.redAccent,
          size: 28,
          bgSize: 60,
          onTap: onDislike,
        ),
        const SizedBox(width: 30),
        // Super Like (Star)
        _ActionButton(
          icon: Icons.shuffle,
          color: Colors.blueAccent,
          size: 24,
          bgSize: 48,
          onTap: onSuperLike,
        ),
        const SizedBox(width: 30),
        // Like (Heart)
        _ActionButton(
          icon: Icons.favorite,
          color: Colors.pinkAccent,
          size: 28,
          bgSize: 60,
          onTap: onLike,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double bgSize;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.bgSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: bgSize,
        height: bgSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
