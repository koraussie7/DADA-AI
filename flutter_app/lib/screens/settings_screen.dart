import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiEnabled = true;
  bool _e2eeEnabled = true;
  String _localAiUrl = 'http://localhost:8080';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
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
                    const Text(
                      '내 노드',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Peer ID: 12D3KooW...abcd',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // P2P settings
          _sectionHeader('P2P 네트워크'),
          _settingTile(
            icon: Icons.wifi,
            title: '연결된 피어',
            subtitle: '2개 피어 연결됨',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF4CAF50)),
                  SizedBox(width: 4),
                  Text('온라인', style: TextStyle(fontSize: 12, color: Color(0xFF4CAF50))),
                ],
              ),
            ),
          ),
          _settingTile(
            icon: Icons.shield,
            title: '종단간 암호화',
            subtitle: 'Noise Protocol + X25519',
            trailing: Switch(
              value: _e2eeEnabled,
              onChanged: (v) => setState(() => _e2eeEnabled = v),
              activeColor: const Color(0xFFFEE500),
            ),
          ),
          _settingTile(
            icon: Icons.storage,
            title: '메시지 저장',
            subtitle: '로컬 SQLite',
            trailing: const Text(
              '24MB 사용 중',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 12),

          // AI settings
          _sectionHeader('AI 설정'),
          _settingTile(
            icon: Icons.auto_awesome,
            title: 'AI 어시스턴트',
            subtitle: 'LocalAI + Gemma-2-2B',
            trailing: Switch(
              value: _aiEnabled,
              onChanged: (v) => setState(() => _aiEnabled = v),
              activeColor: const Color(0xFFFEE500),
            ),
          ),
          _settingTile(
            icon: Icons.link,
            title: 'AI 서버 주소',
            subtitle: _localAiUrl,
            trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
            onTap: () => _editAiUrl(context),
          ),

          const SizedBox(height: 12),

          // About
          _sectionHeader('정보'),
          _settingTile(
            icon: Icons.info_outline,
            title: '버전',
            subtitle: 'Liberty Reach v0.1.0',
          ),
          _settingTile(
            icon: Icons.menu_book,
            title: '문서',
            subtitle: 'Obsidian Vault에서 보기',
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
        title: const Text('AI 서버 주소'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://localhost:8080',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _localAiUrl = controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
