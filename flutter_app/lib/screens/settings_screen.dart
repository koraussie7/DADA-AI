import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/p2p_service.dart';
import '../services/liberty_bridge.dart';
import '../core/constants/app_constants.dart';
import '../core/design_system/app_colors.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/language_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiEnabled = true;
  bool _e2eeEnabled = true;
  String _localAiUrl = AppConstants.defaultAIUrl;

  @override
  Widget build(BuildContext context) {
    final p2p = context.watch<P2PService>();
    final bridge = context.watch<LibertyBridge>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = context.watch<ThemeMode>();
    final langProvider = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(20),
            color: isDark ? AppColors.surfaceLight : Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFFEE500),
                  child: const Icon(Icons.person, size: 32, color: Colors.black54),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).myNode,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocalizations.of(context).peerId}: ${bridge.peerId ?? p2p.localPeerId ?? '12D3KooW...abcd'}',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Appearance
          _sectionHeader(AppLocalizations.of(context).appearance),
          _settingTile(
            icon: isDark ? Icons.dark_mode : Icons.light_mode,
            title: AppLocalizations.of(context).theme,
            subtitle: isDark ? AppLocalizations.of(context).darkMode : AppLocalizations.of(context).lightMode,
            trailing: Switch(
              value: isDark,
              onChanged: (v) {
                if (v) {
                  context.read<ValueNotifier<ThemeMode>>().value = ThemeMode.dark;
                } else {
                  context.read<ValueNotifier<ThemeMode>>().value = ThemeMode.light;
                }
              },
              activeColor: const Color(0xFFFEE500),
            ),
          ),

          const SizedBox(height: 12),

          // Language
          _sectionHeader(AppLocalizations.of(context).language),
          _settingTile(
            icon: Icons.language,
            title: AppLocalizations.of(context).language,
            subtitle: langProvider.locale.languageCode == 'ko' ? '한국어' : 'English',
            trailing: DropdownButton<String>(
              value: langProvider.locale.languageCode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ko', child: Text('한국어')),
              ],
              onChanged: (v) {
                if (v != null) {
                  context.read<LanguageProvider>().setLocale(Locale(v));
                }
              },
            ),
          ),

          const SizedBox(height: 12),

          // P2P settings
          _sectionHeader(AppLocalizations.of(context).p2pNetwork),
          _settingTile(
            icon: Icons.wifi,
            title: AppLocalizations.of(context).connectedPeers,
            subtitle: '${p2p.connectedPeers.length} ${AppLocalizations.of(context).peersConnected}',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (p2p.isConnected ? const Color(0xFF4CAF50) : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8,
                      color: p2p.isConnected ? const Color(0xFF4CAF50) : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    p2p.isConnected ? AppLocalizations.of(context).online : AppLocalizations.of(context).offline,
                    style: TextStyle(fontSize: 12,
                        color: p2p.isConnected ? const Color(0xFF4CAF50) : Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          if (!p2p.isConnected)
            _settingTile(
              icon: Icons.link,
              title: AppLocalizations.of(context).connectToServer,
              subtitle: p2p.isConnecting ? AppLocalizations.of(context).connecting : AppLocalizations.of(context).tapToConnect,
              onTap: p2p.isConnecting ? null : () => p2p.connect(AppConstants.apiBaseUrl),
            ),
          _settingTile(
            icon: Icons.shield,
            title: AppLocalizations.of(context).endToEndEncryption,
            subtitle: 'Noise Protocol + X25519',
            trailing: Switch(
              value: _e2eeEnabled,
              onChanged: (v) => setState(() => _e2eeEnabled = v),
              activeColor: const Color(0xFFFEE500),
            ),
          ),
          _settingTile(
            icon: Icons.storage,
            title: AppLocalizations.of(context).messageStorage,
            subtitle: 'Local persistence (SharedPreferences)',
          ),

          const SizedBox(height: 12),

          // AI settings
          _sectionHeader(AppLocalizations.of(context).aiSettings),
          _settingTile(
            icon: Icons.auto_awesome,
            title: AppLocalizations.of(context).aiAssistant,
            subtitle: 'Gemini 2.5 Flash + LocalAI',
            trailing: Switch(
              value: _aiEnabled,
              onChanged: (v) => setState(() => _aiEnabled = v),
              activeColor: const Color(0xFFFEE500),
            ),
          ),
          _settingTile(
            icon: Icons.link,
            title: AppLocalizations.of(context).aiServerUrl,
            subtitle: _localAiUrl,
            trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
            onTap: () => _editAiUrl(context),
          ),

          const SizedBox(height: 12),

          // About
          _sectionHeader(AppLocalizations.of(context).about),
          _settingTile(
            icon: Icons.info_outline,
            title: AppLocalizations.of(context).version,
            subtitle: 'Liberty Reach v0.1.0',
          ),
          _settingTile(
            icon: Icons.menu_book,
            title: AppLocalizations.of(context).docs,
            subtitle: 'Obsidian Vault',
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.grey[600], size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ),
      trailing: trailing ?? const SizedBox(),
    );
  }

  void _editAiUrl(BuildContext context) {
    final controller = TextEditingController(text: _localAiUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).aiServerUrl),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).aiServerUrl,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              setState(() => _localAiUrl = controller.text);
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }
}
