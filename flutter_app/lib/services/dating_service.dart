import 'dart:math';
import 'package:flutter/foundation.dart';

class UserProfile {
  final String id;
  final String name;
  final int age;
  final String photoUrl;
  final String bio;
  final double distance;
  final List<String> interests;

  UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.photoUrl,
    required this.bio,
    required this.distance,
    required this.interests,
  });
}

class DatingService extends ChangeNotifier {
  static final Random _random = Random();

  static const _photos = [
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400',
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
    'https://images.unsplash.com/photo-1554151228-14d9def656e4?w=400',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
  ];

  static const _names = [
    'Emma', 'Olivia', 'Ava', 'Sophia', 'Liam', 'Noah', 'Oliver', 'Elijah',
    'Mia', 'Charlotte', 'Amelia', 'Harper', 'James', 'Benjamin', 'Lucas', 'Henry',
  ];

  static const _bios = [
    'Artist | Coffee lover',
    'Software Engineer | Hiker',
    'Yoga | Bookworm',
    'Chef | Traveler',
    'Photographer | Nature',
    'Fitness | Music',
    'Painter | Film buff',
    'Writer | Cat person',
    'Surfer | Minimalist',
    'Gamer | Foodie',
  ];

  static const _interests = [
    'Art', 'Travel', 'Music', 'Tech', 'Nature', 'Cooking',
    'Fitness', 'Reading', 'Photography', 'Sports', 'Movies',
    'Gaming', 'Dancing', 'Hiking', 'Coffee',
  ];

  static List<String> get allInterests => [..._interests];

  List<UserProfile> _users = [];
  List<UserProfile> _matches = [];
  bool _isLoading = true;

  // Auth state
  String? _myName;
  int? _myAge;
  String? _myPhotoUrl;

  List<UserProfile> get users => _users;
  List<UserProfile> get matches => _matches;
  bool get isLoading => _isLoading;
  String? get myName => _myName;
  int? get myAge => _myAge;
  String? get myPhotoUrl => _myPhotoUrl;
  bool get isLoggedIn => _myName != null;
  int get matchCount => _matches.length;

  void setProfile({required String name, required int age, required String photoUrl}) {
    _myName = name;
    _myAge = age;
    _myPhotoUrl = photoUrl;
    notifyListeners();
  }

  void loadUsers() {
    _isLoading = true;
    notifyListeners();

    _users = List.generate(16, (i) {
      return UserProfile(
        id: 'user_$i',
        name: _names[i % _names.length],
        age: 18 + _random.nextInt(20),
        photoUrl: _photos[i % _photos.length],
        bio: _bios[_random.nextInt(_bios.length)],
        distance: double.parse((1 + _random.nextDouble() * 15).toStringAsFixed(1)),
        interests: ([..._interests]..shuffle()).take(3 + _random.nextInt(3)).toList(),
      );
    });

    _isLoading = false;
    notifyListeners();
  }

  void like(UserProfile user) {
    _users.removeWhere((u) => u.id == user.id);
    if (_random.nextDouble() < 0.3) {
      _matches.insert(0, user);
    }
    if (_users.isEmpty) {
      loadUsers();
    } else {
      notifyListeners();
    }
  }

  void superLike(UserProfile user) {
    _users.removeWhere((u) => u.id == user.id);
    if (_random.nextDouble() < 0.7) {
      _matches.insert(0, user);
    }
    if (_users.isEmpty) {
      loadUsers();
    } else {
      notifyListeners();
    }
  }

  void dislike(UserProfile user) {
    _users.removeWhere((u) => u.id == user.id);
    if (_users.isEmpty) {
      loadUsers();
    } else {
      notifyListeners();
    }
  }

  void addMoreUsers() {
    loadUsers();
  }
}
