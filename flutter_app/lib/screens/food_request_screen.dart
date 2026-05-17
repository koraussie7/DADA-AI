// lib/screens/food_request_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../services/food_delivery_service.dart';
import '../widgets/location_search_widget.dart';
import 'food_bid_screen.dart';

class FoodRequestScreen extends StatefulWidget {
  const FoodRequestScreen({super.key});

  @override
  State<FoodRequestScreen> createState() => _FoodRequestScreenState();
}

class _FoodRequestScreenState extends State<FoodRequestScreen> {
  // ── Categories ──
  final List<String> _categories = ['All', 'Pizza', 'Burger', 'Fries', 'Salad'];
  String _selectedCategory = 'All';

  // ── Delivery Address ──
  final TextEditingController _addressController = TextEditingController();
  SelectedLocation? _deliveryLocation;

  // ── Budget ──
  double _maxBudget = 25.0; // €5 - €100

  // ── Loading ──
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Load menu from service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<FoodDeliveryService>();
      if (service.menuItems.isEmpty) {
        service.loadMenu();
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  List<MenuItem> _filteredItems(List<MenuItem> items) {
    if (_selectedCategory == 'All') return items;
    return items.where((item) => item.category == _selectedCategory).toList();
  }

  int _cartQty(List<MenuItem> selected, String id) {
    final idx = selected.indexWhere((i) => i.id == id);
    return idx >= 0 ? selected[idx].quantity : 0;
  }

  double _cartTotal(List<MenuItem> selected) {
    return selected.fold(0.0, (sum, item) => sum + item.price * item.quantity);
  }

  // ── Bottom Sheet ──
  void _showItemDetails(BuildContext context, MenuItem item) {
    final service = context.read<FoodDeliveryService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ItemDetailSheet(
        item: item,
        quantity: _cartQty(service.selectedItems, item.id),
        onAdd: () => service.addItem(item),
        onRemove: () => service.removeItem(item),
      ),
    );
  }

  // ── Submit ──
  Future<void> _startBidding() async {
    final service = context.read<FoodDeliveryService>();

    if (_deliveryLocation == null || _deliveryLocation!.formattedAddress.trim().isEmpty) {
      _showSnack('Please enter a delivery address');
      return;
    }
    if (service.selectedItems.isEmpty) {
      _showSnack('Please add at least one item to your order');
      return;
    }

    setState(() => _isSubmitting = true);

    service.setDeliveryLocation(
      address: _deliveryLocation!.formattedAddress,
      lat: _deliveryLocation!.lat,
      lng: _deliveryLocation!.lng,
    );
    service.setMaxBudget(_maxBudget);

    final requestId = await service.createRequest();

    setState(() => _isSubmitting = false);

    if (requestId != null && mounted) {
      service.listenForBids();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodBidScreen(requestId: requestId),
        ),
      );
    } else if (mounted) {
      _showSnack('Failed to create request. Please try again.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final service = context.watch<FoodDeliveryService>();
    final menuItems = service.menuItems;
    final selectedItems = service.selectedItems;
    final filtered = _filteredItems(menuItems);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Food Delivery — Name Your Price'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Category Chips ──
            _buildCategoryChips(),
            const SizedBox(height: 16),

            // ── Menu Grid ──
            if (service.menuLoading)
              _buildMenuLoadingState()
            else
              _buildMenuGrid(filtered, selectedItems, service),

            const SizedBox(height: 24),

            // ── Your Items ──
            if (selectedItems.isNotEmpty) ...[
              _sectionLabel('Your Items'),
              const SizedBox(height: 8),
              _buildCartSection(selectedItems, service),
              const SizedBox(height: 24),
            ],

            // ── Delivery Address ──
            _sectionLabel('Delivery Address'),
            const SizedBox(height: 8),
            _buildAddressField(),
            const SizedBox(height: 24),

            // ── Max Budget ──
            _sectionLabel('Max Budget'),
            const SizedBox(height: 8),
            _buildBudgetSlider(),

            const SizedBox(height: 32),

            // ── Start Bidding Button ──
            _buildSubmitButton(selectedItems.isNotEmpty),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Widget: Menu Loading ──
  Widget _buildMenuLoadingState() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  // ── Widget: Category Chips ──
  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final selected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Widget: Menu Grid ──
  Widget _buildMenuGrid(
      List<MenuItem> items, List<MenuItem> selected, FoodDeliveryService service) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final qty = _cartQty(selected, item.id);
        return _FoodMenuItemCard(
          item: item,
          quantity: qty,
          onTap: () => _showItemDetails(context, item),
          onAdd: () => service.addItem(item),
        );
      },
    );
  }

  // ── Widget: Cart Section ──
  Widget _buildCartSection(List<MenuItem> selected, FoodDeliveryService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          ...selected.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        item.image,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: AppColors.surface,
                          child: const Icon(Icons.fastfood, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '€${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildQuantityControl(item, service),
                  ],
                ),
              )),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '€${_cartTotal(selected).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityControl(MenuItem item, FoodDeliveryService service) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => service.removeItem(item),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                item.quantity <= 1 ? Icons.delete_outline : Icons.remove,
                size: 16,
                color: item.quantity <= 1 ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => service.addItem(item),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.add,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget: Delivery Address (Google Maps) ──
  Widget _buildAddressField() {
    return LocationSearchWidget(
      hintText: 'Search for your delivery address...',
      onLocationSelected: (location) {
        setState(() => _deliveryLocation = location);
      },
    );
  }

  // ── Widget: Budget Slider ──
  Widget _buildBudgetSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Max budget',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              Text(
                '€${_maxBudget.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              valueIndicatorColor: AppColors.primary,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: _maxBudget,
              min: 5,
              max: 100,
              divisions: 95,
              label: '€${_maxBudget.toStringAsFixed(0)}',
              onChanged: (v) => setState(() => _maxBudget = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('€5', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('€100', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Widget: Submit Button ──
  Widget _buildSubmitButton(bool hasItems) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _startBidding,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Start Bidding 🚀',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ── Helper: Section Label ──
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  Food Menu Item Card
// ═══════════════════════════════════════════

class _FoodMenuItemCard extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _FoodMenuItemCard({
    required this.item,
    required this.quantity,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(Icons.fastfood, size: 40, color: AppColors.textMuted),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                  // ── Category Badge ──
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // ── Quantity Badge ──
                  if (quantity > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info ──
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '€${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  Item Detail Bottom Sheet
// ═══════════════════════════════════════════

class _ItemDetailSheet extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ItemDetailSheet({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag Handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      item.image,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: AppColors.surfaceLight,
                        child: const Center(
                          child: Icon(Icons.fastfood, size: 60, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Name & Price ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '€${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Category ──
                  Row(
                    children: [
                      _infoChip(Icons.category_outlined, item.category),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Ingredients ──
                  const Text(
                    'Ingredients',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: item.ingredients.map((ing) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Text(
                        ing,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Quantity Selector ──
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: onRemove,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: quantity <= 1
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: quantity <= 1
                                      ? AppColors.error.withValues(alpha: 0.4)
                                      : AppColors.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(
                                quantity <= 1 ? Icons.delete_outline : Icons.remove,
                                size: 20,
                                color: quantity <= 1 ? AppColors.error : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: onAdd,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
