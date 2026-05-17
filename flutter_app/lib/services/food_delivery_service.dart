import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';

class MenuItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String image;
  final List<String> ingredients;
  int quantity;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    this.ingredients = const [],
    this.quantity = 10,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        image: j['image'] as String? ?? '',
        ingredients: (j['ingredients'] as List?)?.cast<String>() ?? [],
        quantity: (j['quantity'] as int?) ?? 10,
      );

  MenuItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    String? image,
    List<String>? ingredients,
    int? quantity,
  }) =>
      MenuItem(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        image: image ?? this.image,
        ingredients: ingredients ?? this.ingredients,
        quantity: quantity ?? this.quantity,
      );
}

class FoodBid {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final double price;
  final int estimatedMinutes;
  final String message;
  final double rating;
  final DateTime submittedAt;

  FoodBid({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.price,
    required this.estimatedMinutes,
    this.message = '',
    this.rating = 0.0,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  factory FoodBid.fromJson(Map<String, dynamic> j) => FoodBid(
        id: j['id'] as String? ?? '',
        restaurantId: j['restaurant_id'] as String? ?? '',
        restaurantName: j['restaurant_name'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        estimatedMinutes: j['estimated_minutes'] as int? ?? 30,
        message: j['message'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
        submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? ''),
      );
}

class FoodDeliveryService extends ChangeNotifier {
  final http.Client _client = http.Client();
  final String _baseUrl = AppConstants.apiBaseUrl;

  List<MenuItem> _menuItems = [];
  final List<MenuItem> _selectedItems = [];
  List<FoodBid> _bids = [];
  String? _selectedRestaurantId;
  String _deliveryAddress = '';
  double _deliveryLat = 0.0;
  double _deliveryLng = 0.0;
  double _maxBudget = 20.0;
  int _remainingSeconds = 300;
  bool _menuLoading = false;
  String? _currentRequestId;
  Timer? _countdownTimer;
  Timer? _pollTimer;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  List<MenuItem> get selectedItems => List.unmodifiable(_selectedItems);
  List<FoodBid> get bids => List.unmodifiable(_bids);
  String? get selectedRestaurantId => _selectedRestaurantId;
  String get deliveryAddress => _deliveryAddress;
  String get lastAddress => _deliveryAddress;
  double get deliveryLat => _deliveryLat;
  double get deliveryLng => _deliveryLng;
  double get maxBudget => _maxBudget;
  int get remainingSeconds => _remainingSeconds;
  bool get menuLoading => _menuLoading;
  String? get currentRequestId => _currentRequestId;

  double get selectedTotal =>
      _selectedItems.fold(0.0, (sum, item) => sum + item.price);

  bool get hasActiveRequest => _currentRequestId != null && _remainingSeconds > 0;

  // ---------------------------------------------------------------------------
  // Load mock menu
  // ---------------------------------------------------------------------------
  void loadMenu() {
    _menuLoading = true;
    notifyListeners();

    _menuItems = [
      // ---- Pizza ----
      MenuItem(
        id: 'pizza_01',
        name: 'Margherita Pizza',
        category: 'Pizza',
        price: 12.99,
        image:
            'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&h=300&fit=crop',
        ingredients: ['Tomato sauce', 'Fresh mozzarella', 'Basil', 'Olive oil'],
        quantity: 10,
      ),
      MenuItem(
        id: 'pizza_02',
        name: 'Pepperoni Pizza',
        category: 'Pizza',
        price: 14.99,
        image:
            'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=400&h=300&fit=crop',
        ingredients: ['Tomato sauce', 'Mozzarella', 'Pepperoni', 'Oregano'],
        quantity: 8,
      ),
      MenuItem(
        id: 'pizza_03',
        name: 'BBQ Chicken Pizza',
        category: 'Pizza',
        price: 15.99,
        image:
            'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&h=300&fit=crop',
        ingredients: [
          'BBQ sauce',
          'Grilled chicken',
          'Red onion',
          'Cilantro',
          'Mozzarella',
        ],
        quantity: 6,
      ),
      MenuItem(
        id: 'pizza_04',
        name: 'Veggie Supreme Pizza',
        category: 'Pizza',
        price: 13.49,
        image:
            'https://images.unsplash.com/photo-1604382355076-af4b0eb60143?w=400&h=300&fit=crop',
        ingredients: [
          'Tomato sauce',
          'Bell peppers',
          'Mushrooms',
          'Olives',
          'Onions',
        ],
        quantity: 7,
      ),

      // ---- Burger ----
      MenuItem(
        id: 'burger_01',
        name: 'Classic Cheeseburger',
        category: 'Burger',
        price: 9.99,
        image:
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop',
        ingredients: ['Beef patty', 'Cheddar cheese', 'Lettuce', 'Tomato', 'Pickles'],
        quantity: 15,
      ),
      MenuItem(
        id: 'burger_02',
        name: 'Bacon Deluxe Burger',
        category: 'Burger',
        price: 12.49,
        image:
            'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=400&h=300&fit=crop',
        ingredients: [
          'Beef patty',
          'Smoked bacon',
          'Swiss cheese',
          'Caramelized onions',
          'BBQ sauce',
        ],
        quantity: 10,
      ),
      MenuItem(
        id: 'burger_03',
        name: 'Grilled Chicken Burger',
        category: 'Burger',
        price: 10.49,
        image:
            'https://images.unsplash.com/photo-1606755962773-d3245690a5aa?w=400&h=300&fit=crop',
        ingredients: [
          'Grilled chicken breast',
          'Lettuce',
          'Tomato',
          'Mayonnaise',
          'Whole wheat bun',
        ],
        quantity: 12,
      ),
      MenuItem(
        id: 'burger_04',
        name: 'Veggie Black Bean Burger',
        category: 'Burger',
        price: 8.99,
        image:
            'https://images.unsplash.com/photo-1586816001966-79b736744398?w=400&h=300&fit=crop',
        ingredients: [
          'Black bean patty',
          'Avocado',
          'Lettuce',
          'Vegan mayo',
          'Sesame bun',
        ],
        quantity: 9,
      ),

      // ---- Fries ----
      MenuItem(
        id: 'fries_01',
        name: 'Classic French Fries',
        category: 'Fries',
        price: 4.99,
        image:
            'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&h=300&fit=crop',
        ingredients: ['Potatoes', 'Sea salt', 'Vegetable oil'],
        quantity: 20,
      ),
      MenuItem(
        id: 'fries_02',
        name: 'Curly Fries',
        category: 'Fries',
        price: 5.49,
        image:
            'https://images.unsplash.com/photo-1619844175408-c05948185de9?w=400&h=300&fit=crop',
        ingredients: ['Potatoes', 'Paprika', 'Garlic powder', 'Onion powder'],
        quantity: 15,
      ),
      MenuItem(
        id: 'fries_03',
        name: 'Sweet Potato Fries',
        category: 'Fries',
        price: 5.99,
        image:
            'https://images.unsplash.com/photo-1557844352-761f2565b576?w=400&h=300&fit=crop',
        ingredients: ['Sweet potatoes', 'Cinnamon', 'Brown sugar', 'Sea salt'],
        quantity: 12,
      ),
      MenuItem(
        id: 'fries_04',
        name: 'Loaded Chili Cheese Fries',
        category: 'Fries',
        price: 7.99,
        image:
            'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=400&h=300&fit=crop',
        ingredients: [
          'French fries',
          'Beef chili',
          'Cheddar cheese',
          'Sour cream',
          'Chives',
        ],
        quantity: 8,
      ),

      // ---- Salad ----
      MenuItem(
        id: 'salad_01',
        name: 'Caesar Salad',
        category: 'Salad',
        price: 7.99,
        image:
            'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=400&h=300&fit=crop',
        ingredients: [
          'Romaine lettuce',
          'Parmesan cheese',
          'Croutons',
          'Caesar dressing',
        ],
        quantity: 15,
      ),
      MenuItem(
        id: 'salad_02',
        name: 'Greek Salad',
        category: 'Salad',
        price: 8.49,
        image:
            'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400&h=300&fit=crop',
        ingredients: [
          'Cucumber',
          'Tomato',
          'Feta cheese',
          'Olives',
          'Red onion',
          'Olive oil',
        ],
        quantity: 12,
      ),
      MenuItem(
        id: 'salad_03',
        name: 'Garden Fresh Salad',
        category: 'Salad',
        price: 6.99,
        image:
            'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=300&fit=crop',
        ingredients: [
          'Mixed greens',
          'Carrots',
          'Cherry tomatoes',
          'Cucumber',
          'Balsamic vinaigrette',
        ],
        quantity: 18,
      ),
      MenuItem(
        id: 'salad_04',
        name: 'Grilled Chicken Avocado Salad',
        category: 'Salad',
        price: 10.99,
        image:
            'https://images.unsplash.com/photo-1550408065-0a0cefc7d6b0?w=400&h=300&fit=crop',
        ingredients: [
          'Grilled chicken',
          'Avocado',
          'Mixed greens',
          'Corn',
          'Black beans',
          'Lime dressing',
        ],
        quantity: 10,
      ),
    ];

    _menuLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cart management
  // ---------------------------------------------------------------------------
  void addItem(MenuItem item) {
    final existingIndex = _selectedItems.indexWhere((i) => i.id == item.id);
    if (existingIndex >= 0) {
      final existing = _selectedItems[existingIndex];
      _selectedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + 1,
      );
    } else {
      _selectedItems.add(item.copyWith(quantity: 1));

      // Decrement stock from menu
      final menuIndex = _menuItems.indexWhere((i) => i.id == item.id);
      if (menuIndex >= 0 && _menuItems[menuIndex].quantity > 0) {
        _menuItems[menuIndex].quantity -= 1;
      }
    }
    notifyListeners();
  }

  void removeItem(MenuItem item) {
    final existingIndex = _selectedItems.indexWhere((i) => i.id == item.id);
    if (existingIndex < 0) return;

    final existing = _selectedItems[existingIndex];
    if (existing.quantity > 1) {
      _selectedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity - 1,
      );
    } else {
      _selectedItems.removeAt(existingIndex);
    }

    // Restore stock to menu
    final menuIndex = _menuItems.indexWhere((i) => i.id == item.id);
    if (menuIndex >= 0) {
      _menuItems[menuIndex].quantity += 1;
    }

    notifyListeners();
  }

  void updateQuantity(String id, int qty) {
    final index = _selectedItems.indexWhere((i) => i.id == id);
    if (index < 0) return;

    if (qty <= 0) {
      _selectedItems.removeAt(index);
    } else {
      _selectedItems[index] = _selectedItems[index].copyWith(quantity: qty);
    }
    notifyListeners();
  }

  void clearCart() {
    _selectedItems.clear();
    // Reload all menu quantities back to original
    for (int i = 0; i < _menuItems.length; i++) {
      _menuItems[i] = _menuItems[i].copyWith(quantity: _getOriginalQuantity(_menuItems[i].id));
    }
    notifyListeners();
  }

  int _getOriginalQuantity(String id) {
    // Default quantities defined in loadMenu()
    const defaults = {
      'pizza_01': 10, 'pizza_02': 8, 'pizza_03': 6, 'pizza_04': 7,
      'burger_01': 15, 'burger_02': 10, 'burger_03': 12, 'burger_04': 9,
      'fries_01': 20, 'fries_02': 15, 'fries_03': 12, 'fries_04': 8,
      'salad_01': 15, 'salad_02': 12, 'salad_03': 18, 'salad_04': 10,
    };
    return defaults[id] ?? 10;
  }

  // ---------------------------------------------------------------------------
  // Delivery configuration
  // ---------------------------------------------------------------------------
  void setDeliveryAddress(String address) {
    _deliveryAddress = address;
    notifyListeners();
  }

  void setDeliveryLocation({
    required String address,
    required double lat,
    required double lng,
  }) {
    _deliveryAddress = address;
    _deliveryLat = lat;
    _deliveryLng = lng;
    notifyListeners();
  }

  void setMaxBudget(double budget) {
    _maxBudget = budget;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Create food request (InDriver-style bidding)
  // ---------------------------------------------------------------------------
  Future<String?> createRequest() async {
    if (_selectedItems.isEmpty) {
      debugPrint('[FoodDelivery] No items selected.');
      return null;
    }

    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/food/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': _selectedItems
              .map((i) => {
                    'menu_item_id': i.id,
                    'name': i.name,
                    'quantity': i.quantity,
                    'price': i.price,
                  })
              .toList(),
          'delivery_address': _deliveryAddress,
          'delivery_lat': _deliveryLat,
          'delivery_lng': _deliveryLng,
          'max_budget': _maxBudget,
          'total': selectedTotal,
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final reqId = data['request_id'] as String;
        _currentRequestId = reqId;
        _bids = [];
        _selectedRestaurantId = null;
        _startCountdown();
        notifyListeners();
        debugPrint('[FoodDelivery] Request created: $reqId');
        return reqId;
      } else {
        debugPrint('[FoodDelivery] createRequest failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('[FoodDelivery] createRequest error: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Listen for bids (polling)
  // ---------------------------------------------------------------------------
  void listenForBids() {
    _pollTimer?.cancel();

    if (_currentRequestId == null) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_currentRequestId == null || _remainingSeconds <= 0) {
        _pollTimer?.cancel();
        return;
      }

      try {
        final resp = await _client
            .get(
              Uri.parse('$_baseUrl/food/bids/$_currentRequestId'),
            )
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final bidsList = (data['bids'] as List?) ?? [];
          bool changed = false;

          for (final b in bidsList) {
            final bid = FoodBid.fromJson(b as Map<String, dynamic>);
            if (!_bids.any((existing) => existing.id == bid.id)) {
              _bids.add(bid);
              changed = true;
            }
          }

          if (changed) {
            _bids.sort((a, b) => a.price.compareTo(b.price));
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('[FoodDelivery] listenForBids error: $e');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Select a bid
  // ---------------------------------------------------------------------------
  Future<bool> selectBid(String bidId) async {
    if (_currentRequestId == null) return false;

    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/food/select/$_currentRequestId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'restaurant_id': bidId}),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        _selectedRestaurantId = bidId;
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        notifyListeners();
        debugPrint('[FoodDelivery] Bid selected: $bidId');
        return true;
      }
    } catch (e) {
      debugPrint('[FoodDelivery] selectBid error: $e');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Hermes AI recommendation (mock)
  // ---------------------------------------------------------------------------
  String hermesRecommendation() {
    if (_bids.isEmpty) {
      return 'No bids available yet. Please wait for restaurants to respond.';
    }

    final bestBid = _bids.first; // sorted by price ascending
    final bestValue = _bids.reduce((a, b) {
      final scoreA = (a.rating * 0.4) + ((1.0 / a.price) * 0.3) +
          ((1.0 / a.estimatedMinutes) * 0.3);
      final scoreB = (b.rating * 0.4) + ((1.0 / b.price) * 0.3) +
          ((1.0 / b.estimatedMinutes) * 0.3);
      return scoreA >= scoreB ? a : b;
    });

    return '🤖 **Hermes Recommendation**\n\n'
        'Based on price, rating, and estimated delivery time, '
        'I recommend **${bestValue.restaurantName}** '
        '(\$${bestValue.price.toStringAsFixed(2)}, '
        '~${bestValue.estimatedMinutes} min, '
        '⭐${bestValue.rating.toStringAsFixed(1)}).\n\n'
        'If you want the cheapest option, go with **${bestBid.restaurantName}** '
        'at \$${bestBid.price.toStringAsFixed(2)} '
        '(~${bestBid.estimatedMinutes} min, '
        '⭐${bestBid.rating.toStringAsFixed(1)}).';
  }

  // with AI service integration like hotel_service.dart
  /* Future<String?> hermesRecommendationAI() async {
    if (_bids.isEmpty) return null;
    final ai = HybridAIService();
    final prompt = 'Food delivery bids:\n'
        '${_bids.map((b) => "- ${b.restaurantName}: \$${b.price}, "
            "rating ${b.rating}, est. ${b.estimatedMinutes} min, "
            "message: ${b.message}").join("\n")}\n'
        'Recommend the best choice and explain why.';
    final result = await ai.process(prompt);
    return result;
  } */

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------
  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        _currentRequestId = null;
      }
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------
  void reset() {
    _currentRequestId = null;
    _bids = [];
    _selectedRestaurantId = null;
    _remainingSeconds = 300;
    _menuItems = [];
    _selectedItems.clear();
    _deliveryAddress = '';
    _maxBudget = 20.0;
    _menuLoading = false;
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
