// lib/screens/hotel_request_screen.dart
import 'package:flutter/material.dart';
import '../core/design_system/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../widgets/location_search_widget.dart';
import 'hotel_bid_screen.dart';

class HotelRequestScreen extends StatefulWidget {
  const HotelRequestScreen({super.key});

  @override
  State<HotelRequestScreen> createState() => _HotelRequestScreenState();
}

class _HotelRequestScreenState extends State<HotelRequestScreen> {
  // ── Date ──
  DateTime? _checkIn;
  DateTime? _checkOut;

  // ── Guests ──
  int _adults = 2;
  int _children = 0;

  // ── Budget ──
  double _budget = 150; // USD/night

  // ── Location ──
  SelectedLocation? _destinationLocation;

  // ── Amenities ──
  final Map<String, bool> _amenities = {
    'WiFi': false,
    'Breakfast': false,
    'Pool': false,
    'Parking': false,
    'Gym': false,
    'Spa': false,
  };

  @override
  void dispose() {
    super.dispose();
  }

  // ── Date Picker ──
  Future<void> _pickDate({required bool isCheckIn}) async {
    final now = DateTime.now();
    final initial = isCheckIn
        ? (_checkIn ?? now)
        : (_checkOut ?? _checkIn ?? now);
    final first = isCheckIn ? now : (_checkIn ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkIn = picked;
          if (_checkOut != null && _checkOut!.isBefore(picked)) {
            _checkOut = null;
          }
        } else {
          _checkOut = picked;
        }
      });
    }
  }

  // ── Guest Controls ──
  void _changeAdults(int delta) {
    setState(() {
      _adults = (_adults + delta).clamp(1, 10);
    });
  }

  void _changeChildren(int delta) {
    setState(() {
      _children = (_children + delta).clamp(0, 10);
    });
  }

  // ── Amenities Toggle ──
  void _toggleAmenity(String key) {
    setState(() {
      _amenities[key] = !(_amenities[key] ?? false);
    });
  }

  // ── Submit ──
  void _submit() {
    if (_checkIn == null || _checkOut == null) {
      _showSnack('Please select check-in and check-out dates');
      return;
    }
    if (_destinationLocation == null) {
      _showSnack('Please enter a destination');
      return;
    }

    final selectedAmenities = _amenities.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Navigate to HotelBidScreen with data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelBidScreen(
          requestId: '', // Will get from booking result
        ),
      ),
    );
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

  // ── Helpers ──
  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Tap to select';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Hotel Request'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section: Destination ──
            _sectionLabel('Destination'),
            const SizedBox(height: 8),
            _buildLocationField(),

            const SizedBox(height: 24),

            // ── Section: Dates ──
            _sectionLabel('Check-in & Check-out'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDateCard('Check-in', _checkIn, () => _pickDate(isCheckIn: true))),
                const SizedBox(width: 12),
                Expanded(child: _buildDateCard('Check-out', _checkOut, () => _pickDate(isCheckIn: false))),
              ],
            ),

            const SizedBox(height: 24),

            // ── Section: Guests ──
            _sectionLabel('Guests'),
            const SizedBox(height: 8),
            _buildGuestRow('Adults', _adults, _changeAdults),
            const SizedBox(height: 12),
            _buildGuestRow('Children', _children, _changeChildren),

            const SizedBox(height: 24),

            // ── Section: Budget ──
            _sectionLabel('Budget (per night)'),
            const SizedBox(height: 8),
            _buildBudgetSlider(),

            const SizedBox(height: 24),

            // ── Section: Amenities ──
            _sectionLabel('Amenities'),
            const SizedBox(height: 8),
            _buildAmenitiesGrid(),

            const SizedBox(height: 32),

            // ── Submit Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Search Hotels',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Widgets ──

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

  Widget _buildLocationField() {
    return LocationSearchWidget(
      hintText: 'Where are you going?',
      onLocationSelected: (location) {
        setState(() => _destinationLocation = location);
      },
    );
  }

  Widget _buildDateCard(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: date != null
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: date != null ? AppColors.primary : AppColors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: TextStyle(
                      color: date != null ? Colors.white : AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestRow(String label, int count, void Function(int) onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _buildCircleButton(Icons.remove, count > (label == 'Adults' ? 1 : 0), () => onChange(-1)),
          const SizedBox(width: 16),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          _buildCircleButton(Icons.add, count < 10, () => onChange(1)),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }

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
                'Max per night',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              Text(
                '\$${_budget.round()}',
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
            ),
            child: Slider(
              value: _budget,
              min: 30,
              max: 1000,
              divisions: 97,
              label: '\$${_budget.round()}',
              onChanged: (v) => setState(() => _budget = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('\$30', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('\$1000', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesGrid() {
    final entries = _amenities.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final selected = entry.value;
        return GestureDetector(
          onTap: () => _toggleAmenity(entry.key),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _amenityIcon(entry.key),
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _amenityIcon(String name) {
    switch (name) {
      case 'WiFi':
        return Icons.wifi;
      case 'Breakfast':
        return Icons.free_breakfast;
      case 'Pool':
        return Icons.pool;
      case 'Parking':
        return Icons.local_parking;
      case 'Gym':
        return Icons.fitness_center;
      case 'Spa':
        return Icons.spa;
      default:
        return Icons.check_circle_outline;
    }
  }
}
