import 'package:flutter/material.dart';

/// Categories for organizing drawer menu items
enum DrawerCategory { services, hyperspace, more }

/// Data model for a drawer menu item
class _DrawerItem {
  final String label;
  final IconData icon;
  final String? routeName;
  final DrawerCategory category;
  final Color? accentColor;

  const _DrawerItem({
    required this.label,
    required this.icon,
    this.routeName,
    this.category = DrawerCategory.more,
    this.accentColor,
  });
}

/// Animated sliding drawer for DADA-AI
class DADADrawer extends StatefulWidget {
  final int currentIndex;
  final void Function(int index, String? routeName) onItemSelected;

  const DADADrawer({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  State<DADADrawer> createState() => _DADADrawerState();
}

class _DADADrawerState extends State<DADADrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int? _hoveredIndex;

  // ── Full drawer menu items ──────────────────────────────────────
  List<_DrawerItem> get _items => [
        // Category: Services
        _DrawerItem(
          label: 'DS Dashboard',
          icon: Icons.dashboard_rounded,
          routeName: '/ds/dashboard',
          category: DrawerCategory.services,
          accentColor: const Color(0xFF8B5CF6),
        ),
        _DrawerItem(
          label: 'Reward',
          icon: Icons.card_giftcard_rounded,
          routeName: '/reward',
          category: DrawerCategory.services,
          accentColor: const Color(0xFFF59E0B),
        ),
        _DrawerItem(
          label: 'Wallet',
          icon: Icons.wallet_rounded,
          routeName: '/wallet',
          category: DrawerCategory.services,
          accentColor: const Color(0xFF10B981),
        ),
        _DrawerItem(
          label: 'Blockchain',
          icon: Icons.account_balance_rounded,
          routeName: '/blockchain/dashboard',
          category: DrawerCategory.services,
          accentColor: const Color(0xFF3B82F6),
        ),
        _DrawerItem(
          label: 'Vector Map',
          icon: Icons.map_rounded,
          routeName: '/map/vector',
          category: DrawerCategory.services,
          accentColor: const Color(0xFF22D3EE),
        ),

        // Category: Hyperspace
        _DrawerItem(
          label: 'AI Chat',
          icon: Icons.psychology_rounded,
          routeName: '/hyperspace/chat',
          category: DrawerCategory.hyperspace,
          accentColor: const Color(0xFFF02C56),
        ),
        _DrawerItem(
          label: 'Pod',
          icon: Icons.cell_tower_rounded,
          routeName: '/hyperspace/pod',
          category: DrawerCategory.hyperspace,
          accentColor: const Color(0xFFEC4899),
        ),
        _DrawerItem(
          label: 'Earnings',
          icon: Icons.trending_up_rounded,
          routeName: '/hyperspace/earnings',
          category: DrawerCategory.hyperspace,
          accentColor: const Color(0xFF22D3EE),
        ),

        // Category: More
        _DrawerItem(
          label: 'Create Account',
          icon: Icons.person_add_rounded,
          routeName: '/auth/signup',
          category: DrawerCategory.more,
          accentColor: const Color(0xFF6B46C1),
        ),
        _DrawerItem(
          label: 'Contacts',
          icon: Icons.people_alt_rounded,
          routeName: '/contacts',
          category: DrawerCategory.more,
          accentColor: const Color(0xFFA78BFA),
        ),
        _DrawerItem(
          label: 'Settings',
          icon: Icons.settings_rounded,
          routeName: '/settings',
          category: DrawerCategory.more,
          accentColor: const Color(0xFF94A3B8),
        ),
        _DrawerItem(
          label: 'Business',
          icon: Icons.business_center_rounded,
          routeName: '/supplier/dashboard',
          category: DrawerCategory.more,
          accentColor: const Color(0xFFF97316),
        ),
        _DrawerItem(
          label: 'Admin',
          icon: Icons.admin_panel_settings_rounded,
          routeName: '/admin/point',
          category: DrawerCategory.more,
          accentColor: const Color(0xFFEF4444),
        ),
      ];

  Map<DrawerCategory, String> get _categoryLabels => {
        DrawerCategory.services: 'Services',
        DrawerCategory.hyperspace: 'Hyperspace',
        DrawerCategory.more: 'More',
      };

  Map<DrawerCategory, IconData> get _categoryIcons => {
        DrawerCategory.services: Icons.apps_rounded,
        DrawerCategory.hyperspace: Icons.auto_awesome_rounded,
        DrawerCategory.more: Icons.more_horiz_rounded,
      };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void animateIn() {
    _animCtrl.forward(from: 0);
  }

  void animateOut() {
    _animCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFF1E293B);
    final surfaceColor = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);

    return Container(
      width: MediaQuery.of(context).size.width * 0.78,
      color: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 8),
            // Notification-like divider
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Menu items
            Expanded(
              child: _buildMenuList(surfaceColor),
            ),
            // Bottom version info
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated logo area
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DADA-AI',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Liberty Reach',
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.white).withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuList(Color surfaceColor) {
    final grouped = <DrawerCategory, List<_DrawerItem>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final categories = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: categories.length,
      itemBuilder: (context, catIndex) {
        final entry = categories[catIndex];
        final catItems = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryHeader(entry.key, surfaceColor),
            ...List.generate(catItems.length, (itemIndex) {
              // Compute global index for callback
              int globalIdx = 0;
              int count = 0;
              for (var e in categories) {
                for (int i = 0; i < e.value.length; i++) {
                  if (e.key == entry.key && i == itemIndex) {
                    globalIdx = count;
                  }
                  count++;
                }
              }

              return _buildMenuItem(
                catItems[itemIndex],
                globalIdx,
                entry.key == categories.last &&
                    itemIndex == catItems.length - 1,
              );
            }),
            if (catIndex < categories.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryHeader(DrawerCategory category, Color surfaceColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Row(
        children: [
          Icon(
            _categoryIcons[category],
            size: 14,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 6),
          Text(
            _categoryLabels[category] ?? '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(_DrawerItem item, int index, bool isLast) {
    final isHovered = _hoveredIndex == index;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        final delay = 0.05 * index;
        final rawValue = (_animCtrl.value - delay) / (1 - delay);
        final animValue = rawValue.clamp(0.0, 1.0);
        final opacity = animValue;
        final offset = Offset(-20.0 * (1.0 - animValue), 0.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: offset,
            child: _MenuItemWidget(
              item: item,
              isHovered: isHovered,
              accentColor: item.accentColor ?? Theme.of(context).primaryColor,
              onTap: () {
                widget.onItemSelected(index, item.routeName);
              },
              onHover: (v) {
                setState(() => _hoveredIndex = v ? index : null);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 12,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Text(
            'DADA-AI v0.1',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.code_rounded,
            size: 12,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _MenuItemWidget extends StatelessWidget {
  final _DrawerItem item;
  final bool isHovered;
  final Color accentColor;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _MenuItemWidget({
    required this.item,
    required this.isHovered,
    required this.accentColor,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isHovered
                ? accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isHovered
                ? Border.all(
                    color: accentColor.withValues(alpha: 0.2), width: 1)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Icon with accent glow
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isHovered
                        ? accentColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: isHovered
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isHovered
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight:
                          isHovered ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                // Arrow indicator on hover
                AnimatedOpacity(
                  opacity: isHovered ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: accentColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
