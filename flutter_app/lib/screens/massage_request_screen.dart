// lib/screens/massage_request_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../services/massage_service.dart';
import '../widgets/location_search_widget.dart';
import 'massage_bid_screen.dart';

class MassageRequestScreen extends StatefulWidget {
  const MassageRequestScreen({super.key});

  @override
  State<MassageRequestScreen> createState() => _MassageRequestScreenState();
}

class _MassageRequestScreenState extends State<MassageRequestScreen> {
  SelectedLocation? _location;
  String _serviceType = 'Deep Tissue';
  int _duration = 60;
  double _maxBudget = 80.0;
  bool _isSubmitting = false;

  static const List<String> _serviceTypes = [
    'Deep Tissue', 'Swedish', 'Thai', 'Sports', 'Aromatherapy',
  ];

  static const Map<String, IconData> _serviceIcons = {
    'Deep Tissue': Icons.fitness_center,
    'Swedish': Icons.spa,
    'Thai': Icons.self_improvement,
    'Sports': Icons.directions_run,
    'Aromatherapy': Icons.air,
  };

  Future<void> _startBidding() async {
    final service = context.read<MassageService>();
    if (_location == null) {
      _showSnack('Please enter your location');
      return;
    }
    setState(() => _isSubmitting = true);
    service.setLocation(address: _location!.formattedAddress, lat: _location!.lat, lng: _location!.lng);
    service.setServiceType(_serviceType);
    service.setDuration(_duration);
    service.setMaxBudget(_maxBudget);

    final requestId = await service.createRequest();
    setState(() => _isSubmitting = false);

    if (requestId != null && mounted) {
      service.listenForBids();
      Navigator.push(context, MaterialPageRoute(builder: (_) => MassageBidScreen(requestId: requestId)));
    } else if (mounted) {
      _showSnack('Failed to create request. Try again.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('💆 Massage — Name Your Price'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Service Type
          _sectionLabel('Service Type'),
          const SizedBox(height: 10),
          _buildServiceTypeGrid(),
          const SizedBox(height: 24),

          // Duration
          _sectionLabel('Duration'),
          const SizedBox(height: 8),
          _buildDurationCard(),
          const SizedBox(height: 24),

          // Location
          _sectionLabel('Your Location'),
          const SizedBox(height: 8),
          LocationSearchWidget(
            hintText: 'Where should the therapist come?',
            onLocationSelected: (loc) => setState(() => _location = loc),
          ),
          const SizedBox(height: 24),

          // Budget
          _sectionLabel('Max Budget'),
          const SizedBox(height: 8),
          _buildBudgetCard(),
          const SizedBox(height: 32),

          // Submit
          _buildSubmitButton(),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildServiceTypeGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _serviceTypes.map((type) {
        final selected = type == _serviceType;
        return GestureDetector(
          onTap: () => setState(() => _serviceType = type),
          child: Container(
            width: (MediaQuery.of(context).size.width - 60) / 3,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _serviceIcons[type] ?? Icons.spa,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  type,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Text('Duration', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Row(
                children: [
                  _durationBtn(false, Icons.remove_circle_outline, _duration > 30 ? () => setState(() => _duration -= 15) : null),
                  const SizedBox(width: 12),
                  Text(
                    '${_duration} min',
                    style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  _durationBtn(false, Icons.add_circle_outline, _duration < 180 ? () => setState(() => _duration += 15) : null),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _duration.toDouble(),
              min: 30,
              max: 180,
              divisions: 10,
              label: '$_duration min',
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Text('Max budget', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Text('\$${_maxBudget.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700)),
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
            ),
            child: Slider(
              value: _maxBudget,
              min: 20,
              max: 300,
              divisions: 28,
              label: '\$${_maxBudget.toStringAsFixed(0)}',
              onChanged: (v) => setState(() => _maxBudget = v),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
            Text('\$20', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Text('\$300', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _startBidding,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('🚀 Find a Therapist', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _durationBtn(bool filled, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          shape: BoxShape.circle,
          border: Border.all(color: onTap != null ? AppColors.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(icon, size: 18, color: onTap != null ? AppColors.primary : AppColors.textMuted),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}
