// lib/screens/taxi_request_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../services/taxi_service.dart';
import '../widgets/location_search_widget.dart';
import 'taxi_bid_screen.dart';

class TaxiRequestScreen extends StatefulWidget {
  const TaxiRequestScreen({super.key});

  @override
  State<TaxiRequestScreen> createState() => _TaxiRequestScreenState();
}

class _TaxiRequestScreenState extends State<TaxiRequestScreen> {
  SelectedLocation? _pickupLocation;
  SelectedLocation? _dropoffLocation;
  int _passengers = 1;
  double _maxBudget = 25.0;
  bool _isSubmitting = false;

  // ── Submit ──
  Future<void> _startBidding() async {
    final service = context.read<TaxiService>();

    if (_pickupLocation == null) {
      _showSnack('Please enter a pickup location');
      return;
    }
    if (_dropoffLocation == null) {
      _showSnack('Please enter a dropoff location');
      return;
    }

    setState(() => _isSubmitting = true);

    service.setPickupLocation(
      address: _pickupLocation!.formattedAddress,
      lat: _pickupLocation!.lat,
      lng: _pickupLocation!.lng,
    );
    service.setDropoffLocation(
      address: _dropoffLocation!.formattedAddress,
      lat: _dropoffLocation!.lat,
      lng: _dropoffLocation!.lng,
    );
    service.setPassengers(_passengers);
    service.setMaxBudget(_maxBudget);

    final requestId = await service.createRideRequest();
    setState(() => _isSubmitting = false);

    if (requestId != null && mounted) {
      service.listenForBids();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaxiBidScreen(requestId: requestId),
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('🚗 Taxi — Name Your Price'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pickup Location ──
            _sectionLabel('Pickup Location'),
            const SizedBox(height: 8),
            LocationSearchWidget(
              hintText: 'Where should we pick you up?',
              onLocationSelected: (location) {
                setState(() => _pickupLocation = location);
              },
            ),
            const SizedBox(height: 24),

            // ── Dropoff Location ──
            _sectionLabel('Dropoff Location'),
            const SizedBox(height: 8),
            LocationSearchWidget(
              hintText: 'Where are you going?',
              onLocationSelected: (location) {
                setState(() => _dropoffLocation = location);
              },
            ),
            const SizedBox(height: 24),

            // ── Passengers ──
            _sectionLabel('Passengers'),
            const SizedBox(height: 8),
            _buildPassengersCard(),
            const SizedBox(height: 24),

            // ── Max Budget ──
            _sectionLabel('Max Budget'),
            const SizedBox(height: 8),
            _buildBudgetCard(),
            const SizedBox(height: 32),

            // ── Start Bidding Button ──
            _buildSubmitButton(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengersCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Number of passengers',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  '$_passengers ${_passengers == 1 ? 'passenger' : 'passengers'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconButton(Icons.remove_circle_outline, _passengers > 1
                  ? () => setState(() => _passengers--)
                  : null),
              const SizedBox(width: 8),
              _iconButton(Icons.add_circle_outline, _passengers < 8
                  ? () => setState(() => _passengers++)
                  : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
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
                'Max fare',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              Text(
                '\$${_maxBudget.toStringAsFixed(0)}',
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
              value: _maxBudget,
              min: 5,
              max: 200,
              divisions: 39,
              label: '\$${_maxBudget.toStringAsFixed(0)}',
              onChanged: (v) => setState(() => _maxBudget = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('\$5', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('\$200', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                '🚀 Find Me a Ride',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }

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
