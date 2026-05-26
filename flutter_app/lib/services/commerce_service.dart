import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

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

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CommerceService extends ChangeNotifier {
  final String _baseUrl = AppConstants.apiBaseUrl;
  final http.Client _client;

  CommerceService() : _client = http.Client();

  bool _isLive = false;
  int _viewerCount = 0;
  CommerceRecommendation? _currentRecommendation;
  List<Product> _trendingCache = [];
  bool _trendingLoaded = false;
  final List<CartItem> _cart = [];

  bool get isLive => _isLive;
  int get viewerCount => _viewerCount;
  CommerceRecommendation? get currentRecommendation => _currentRecommendation;
  List<Product> get trendingProductsCache => _trendingCache;
  List<CartItem> get cart => List.unmodifiable(_cart);
  int get cartCount => _cart.fold<int>(0, (sum, item) => sum + item.quantity);

  void addToCart(Product product) {
    final idx = _cart.indexWhere((item) => item.product.id == product.id);
    if (idx >= 0) {
      _cart[idx].quantity++;
    } else {
      _cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final idx = _cart.indexWhere((item) => item.product.id == productId);
    if (idx >= 0) {
      if (quantity <= 0) {
        _cart.removeAt(idx);
      } else {
        _cart[idx].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void checkout() {
    _cart.clear();
    notifyListeners();
  }

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
    if (_trendingLoaded) return _trendingCache;
    try {
      final resp = await _client
          .get(Uri.parse('$_baseUrl/commerce/trending'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List? ?? [];
        _trendingCache = list.map((e) => Product.fromJson(e)).toList();
        _trendingLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Commerce] trending error: $e');
    }
    return _trendingCache;
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
