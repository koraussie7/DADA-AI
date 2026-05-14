import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/design_system.dart';
import '../services/wallet_service.dart';
import '../services/commerce_service.dart';

class RewardDashboard extends StatefulWidget {
  final void Function(int tab)? onNavigate;
  const RewardDashboard({super.key, this.onNavigate});

  @override
  State<RewardDashboard> createState() => _RewardDashboardState();
}

class _RewardDashboardState extends State<RewardDashboard>
    with SingleTickerProviderStateMixin {
  int _todayPoints = 0;
  int _totalPoints = 0;
  int _tierIndex = 0;
  Timer? _earningTimer;
  late TabController _commerceTabCtrl;

  final _tiers = ['Explorer', 'Creator', 'Star', 'Architect'];
  final _tierIcons = [Icons.explore, Icons.auto_awesome, Icons.star, Icons.workspace_premium];

  final _sampleProducts = [
    Product(id: '1', name: 'Wireless Earbuds Pro', price: 45000, imageUrl: '', badge: 'HOT', rewardPoints: 300),
    Product(id: '2', name: 'Smart Watch Ultra', price: 89000, imageUrl: '', badge: 'NEW', rewardPoints: 500),
    Product(id: '3', name: 'AI Speaker Mini', price: 32000, imageUrl: '', badge: '50% OFF', rewardPoints: 200),
    Product(id: '4', name: 'LED Desk Lamp', price: 15000, imageUrl: '', rewardPoints: 100),
    Product(id: '5', name: 'Mechanical Keyboard', price: 55000, imageUrl: '', badge: 'BEST', rewardPoints: 400),
  ];

  @override
  void initState() {
    super.initState();
    _commerceTabCtrl = TabController(length: _sampleProducts.length, viewportFraction: 0.4, vsync: this);
    _startEarning();
  }

  void _startEarning() {
    _earningTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final earned = 1 + DateTime.now().millisecondsSinceEpoch % 5;
      setState(() {
        _todayPoints += earned;
        _totalPoints += earned;
        if (_totalPoints >= 1000 && _tierIndex < 1) _tierIndex = 1;
        if (_totalPoints >= 5000 && _tierIndex < 2) _tierIndex = 2;
        if (_totalPoints >= 20000 && _tierIndex < 3) _tierIndex = 3;
      });
    });
  }

  @override
  void dispose() {
    _earningTimer?.cancel();
    _commerceTabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    final commerce = context.watch<CommerceService>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          _buildHeader(wallet, commerce),
          SliverToBoxAdapter(child: _buildPointCard(wallet)),
          SliverToBoxAdapter(child: _buildP2pStatus(commerce)),
          SliverToBoxAdapter(child: _buildLiveCommerceHero(commerce)),
          SliverToBoxAdapter(child: _buildTrendingCommerce()),
          SliverToBoxAdapter(child: _buildMissionGrid(wallet, commerce)),
          SliverToBoxAdapter(child: _buildBottomPadding()),
        ],
      ),
    );
  }

  Widget _buildHeader(WalletService wallet, CommerceService commerce) {
    return SliverAppBar(
      expandedHeight: 56,
      floating: true,
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: commerce.isLive ? Colors.redAccent : AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(commerce.isLive ? 'LIVE' : 'DADA Point',
            style: AppTextStyles.titleMedium(color: AppColors.textPrimary)),
          const Spacer(),
          if (wallet.connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet, size: 14, color: AppColors.primaryLight),
                  const SizedBox(width: 4),
                  Text(wallet.shortAddress, style: AppTextStyles.labelSmall(color: AppColors.primaryLight)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPointCard(WalletService wallet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark.withOpacity(0.8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.accentLight, size: 20),
              const SizedBox(width: 8),
              Text('Today Earned', style: AppTextStyles.bodySmall(color: Colors.white70)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_tierIcons[_tierIndex], size: 12, color: AppColors.accentLight),
                    const SizedBox(width: 4),
                    Text(_tiers[_tierIndex], style: AppTextStyles.labelSmall(color: AppColors.accentLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$_todayPoints', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('DADA', style: AppTextStyles.bodyMedium(color: Colors.white70)),
              ),
              const Spacer(),
              if (!wallet.connected)
                TextButton.icon(
                  onPressed: () => wallet.connect(),
                  icon: const Icon(Icons.link, size: 14, color: Colors.white),
                  label: Text('Connect Wallet', style: AppTextStyles.labelSmall(color: Colors.white)),
                  style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.15)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_totalPoints % 5000) / 5000,
            backgroundColor: Colors.white.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(AppColors.accentLight),
          ),
          const SizedBox(height: 4),
          Text('Total $_totalPoints DADA  •  Next tier in ${5000 - (_totalPoints % 5000)} pts',
            style: AppTextStyles.bodySmall(color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildP2pStatus(CommerceService commerce) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: commerce.isLive ? Colors.redAccent.withOpacity(0.15) : AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (commerce.isLive ? Colors.redAccent : AppColors.success).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: commerce.isLive ? Colors.redAccent : AppColors.success,
                    shape: BoxShape.circle,
                  )),
                const SizedBox(width: 6),
                Text(commerce.isLive ? 'LIVE' : 'P2P Connected',
                  style: AppTextStyles.labelSmall(color: commerce.isLive ? Colors.redAccent : AppColors.success)),
              ],
            ),
          ),
          if (commerce.isLive) ...[
            const SizedBox(width: 8),
            Text('${commerce.viewerCount} watching', style: AppTextStyles.bodySmall(color: AppColors.textMuted)),
          ],
          const Spacer(),
          Text('Hermes AI  ●  Online', style: AppTextStyles.labelSmall(color: AppColors.agentHermes)),
        ],
      ),
    );
  }

  Widget _buildLiveCommerceHero(CommerceService commerce) {
    return GestureDetector(
      onTap: () => _showLiveCommerceSheet(commerce),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.commerceGradientStart, AppColors.commerceGradientEnd],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.commerceGradientStart.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 16, left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 12, color: AppColors.accentLight),
                            const SizedBox(width: 4),
                            Text('AI Hermes', style: AppTextStyles.labelSmall(color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.commerceBadge.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('LIVE', style: AppTextStyles.labelSmall(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('AI Live Commerce', style: AppTextStyles.headlineMedium(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Hermes analyzes & sells automatically', style: AppTextStyles.bodyMedium(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _productTag('Samsung'),
                      const SizedBox(width: 6),
                      _productTag('Apple'),
                      const SizedBox(width: 6),
                      _productTag('AI Gadgets'),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: AppColors.commerceGradientStart, size: 20),
                    const SizedBox(width: 4),
                    Text('AI Live', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.commerceGradientStart)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(label, style: AppTextStyles.labelSmall(color: Colors.white)),
    );
  }

  Widget _buildTrendingCommerce() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: AppColors.commercePrice),
              const SizedBox(width: 6),
              Text('Trending Commerce', style: AppTextStyles.titleMedium()),
              const Spacer(),
              Text('Earn up to 2,000P', style: AppTextStyles.labelSmall(color: AppColors.commercePrice)),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _sampleProducts.length,
            itemBuilder: (_, i) => _buildCommerceCard(_sampleProducts[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCommerceCard(Product product) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 60, width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(Icons.shopping_bag, color: AppColors.primaryLight, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(product.name, style: AppTextStyles.bodyMedium(), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            children: [
              Text('${product.price}P', style: AppTextStyles.labelLarge(color: AppColors.commercePrice)),
              const Spacer(),
              if (product.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.commerceBadge.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(product.badge!, style: AppTextStyles.labelSmall(color: AppColors.commerceBadge)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissionGrid(WalletService wallet, CommerceService commerce) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch, size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 6),
              Text('Missions', style: AppTextStyles.titleMedium()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _missionCard(
                icon: Icons.shopping_cart, label: 'AI Live\nCommerce',
                points: '300~2,000P', color: AppColors.commerceGradientEnd,
                onTap: () => _showLiveCommerceSheet(commerce),
              )),
              const SizedBox(width: 8),
              Expanded(child: _missionCard(
                icon: Icons.people, label: 'Invite\nFriends',
                points: '+500P', color: AppColors.info,
                onTap: () {},
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _missionCard(
                icon: Icons.assignment, label: 'Missions\nup to 5,000P',
                points: '5,000P', color: AppColors.warning,
                onTap: () {},
              )),
              const SizedBox(width: 8),
              Expanded(child: _missionCard(
                icon: Icons.store, label: 'Shop\nRedeem',
                points: 'Shop', color: AppColors.success,
                onTap: () {},
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missionCard({
    required IconData icon, required String label,
    required String points, required Color color, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label, style: AppTextStyles.bodyMedium(color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(points, style: AppTextStyles.labelLarge(color: color)),
          ],
        ),
      ),
    );
  }

  void _showLiveCommerceSheet(CommerceService commerce) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _LiveCommerceSheet(commerce: commerce, sampleProducts: _sampleProducts),
    );
  }

  Widget _buildBottomPadding() => const SizedBox(height: 100);
}

class _LiveCommerceSheet extends StatefulWidget {
  final CommerceService commerce;
  final List<Product> sampleProducts;
  const _LiveCommerceSheet({required this.commerce, required this.sampleProducts});

  @override
  State<_LiveCommerceSheet> createState() => _LiveCommerceSheetState();
}

class _LiveCommerceSheetState extends State<_LiveCommerceSheet> {
  bool _streaming = false;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletService>();
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, color: AppColors.commerceGradientEnd, size: 20),
                const SizedBox(width: 8),
                Text('AI Live Commerce', style: AppTextStyles.titleMedium()),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.commerceBadge.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('HERMES AI', style: AppTextStyles.labelSmall(color: AppColors.commerceBadge)),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.sampleProducts.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _buildStreamToggle(wallet);
                }
                final p = widget.sampleProducts[i - 1];
                return _buildProductItem(p, wallet);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamToggle(WalletService wallet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.commerceGradientStart.withOpacity(0.2), AppColors.commerceGradientEnd.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.commerceGradientStart.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start AI Live Stream', style: AppTextStyles.titleMedium()),
                const SizedBox(height: 4),
                Text('Hermes will auto-tag & sell products', style: AppTextStyles.bodyMedium()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() => _streaming = !_streaming);
              if (_streaming) {
                widget.commerce.startLiveCommerce('live_001', widget.sampleProducts);
              } else {
                widget.commerce.stopLiveCommerce();
              }
            },
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _streaming ? AppColors.commerceBadge : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: _streaming
                    ? [BoxShadow(color: AppColors.commerceBadge.withOpacity(0.4), blurRadius: 12)]
                    : null,
              ),
              child: Icon(
                _streaming ? Icons.stop : Icons.play_arrow,
                color: Colors.white, size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Product product, WalletService wallet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_bag, color: AppColors.primaryLight, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(product.name, style: AppTextStyles.titleMedium())),
                    if (product.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.commerceBadge.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(product.badge!, style: AppTextStyles.labelSmall(color: AppColors.commerceBadge)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${product.price} DADA  •  Earn +${product.rewardPoints}P',
                  style: AppTextStyles.bodyMedium(color: AppColors.commercePrice)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: wallet.connected
                ? () async {
                    final ok = await wallet.sendDada('merchant', product.price, memo: product.name);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Purchased ${product.name}!' : 'Insufficient balance'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ));
                    }
                  }
                : () => wallet.connect(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Buy', style: AppTextStyles.labelSmall(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
