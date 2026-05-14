import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Product {
  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final String? badge;
  final int rewardPoints;

  Product({
    required this.id, required this.name, required this.price,
    required this.imageUrl, this.badge, this.rewardPoints = 0,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id']?.toString() ?? '',
    name: j['name'] as String? ?? '',
    price: j['price'] as int? ?? 0,
    imageUrl: j['image_url'] as String? ?? '',
    badge: j['badge'] as String?,
    rewardPoints: j['reward_points'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'price': price,
    'image_url': imageUrl, if (badge != null) 'badge': badge,
    'reward_points': rewardPoints,
  };
}

class CommerceRecommendation {
  final String videoId;
  final List<Product> products;
  final String? hermesAnalysis;
  final String? recommendation;

  CommerceRecommendation({
    required this.videoId, required this.products,
    this.hermesAnalysis, this.recommendation,
  });

  factory CommerceRecommendation.fromJson(Map<String, dynamic> j) =>
      CommerceRecommendation(
        videoId: j['video_id'] as String? ?? '',
        products: (j['products'] as List? ?? []).map((e) => Product.fromJson(e)).toList(),
        hermesAnalysis: j['hermes_analysis'] as String?,
        recommendation: j['recommendation'] as String?,
      );
}

class CommerceService extends ChangeNotifier {
  final String _baseUrl = 'https://muhantube.com';
  final http.Client _client;

  CommerceService() : _client = http.Client();

  bool _isLive = false;
  int _viewerCount = 0;
  CommerceRecommendation? _currentRecommendation;

  bool get isLive => _isLive;
  int get viewerCount => _viewerCount;
  CommerceRecommendation? get currentRecommendation => _currentRecommendation;

  Future<void> startLiveCommerce(String videoId, List<Product> products) async {
    _isLive = true;
    _viewerCount = 0;
    notifyListeners();
    try {
      final body = {
        'video_id': videoId,
        'products': products.map((e) => e.toJson()).toList(),
      };
      final resp = await _client
          .post(Uri.parse('$_baseUrl/commerce/analyze'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        _currentRecommendation =
            CommerceRecommendation.fromJson(jsonDecode(resp.body));
      }
    } catch (e) {
      debugPrint('[Commerce] analyze error: $e');
    }
    notifyListeners();
  }

  void stopLiveCommerce() {
    _isLive = false;
    _viewerCount = 0;
    _currentRecommendation = null;
    notifyListeners();
  }

  void incrementViewer() {
    _viewerCount++;
    notifyListeners();
  }

  Future<List<Product>> trendingProducts() async {
    try {
      final resp = await _client
          .get(Uri.parse('$_baseUrl/commerce/trending'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List? ?? [];
        return list.map((e) => Product.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[Commerce] trending error: $e');
    }
    return [];
  }

  Future<String?> hermesAnalysis(String videoId) async {
    try {
      final resp = await _client
          .post(Uri.parse('$_baseUrl/commerce/hermes-analyze'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'video_id': videoId}))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['analysis'] as String?;
      }
    } catch (e) {
      debugPrint('[Commerce] hermes error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
