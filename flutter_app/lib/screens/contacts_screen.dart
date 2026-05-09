import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('연락처'),
        automaticallyImplyLeading: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _contacts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final c = _contacts[index];
          return ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    peerId: c.peerId,
                    peerName: c.name,
                    isAI: false,
                  ),
                ),
              );
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              child: Text(
                c.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
            title: Text(
              c.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.isOnline ? const Color(0xFF4CAF50) : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.isOnline ? '온라인' : '오프라인',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (c.peerId != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'ID: ${c.peerId}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ],
              ),
            ),
            trailing: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
          );
        },
      ),
    );
  }
}

class _Contact {
  final String name;
  final bool isOnline;
  final String? peerId;
  const _Contact({required this.name, required this.isOnline, this.peerId});
}

const _contacts = [
  _Contact(name: 'AI 어시스턴트', isOnline: true, peerId: 'ai-assistant'),
  _Contact(name: '앨리스', isOnline: true, peerId: 'alice'),
  _Contact(name: '밥', isOnline: false, peerId: 'bob'),
  _Contact(name: '찰리', isOnline: true, peerId: 'charlie'),
  _Contact(name: 'Node 1', isOnline: true, peerId: 'node-1'),
  _Contact(name: 'Node 2', isOnline: false, peerId: 'node-2'),
];
