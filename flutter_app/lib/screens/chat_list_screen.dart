import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final List<ChatRoom> _rooms = [
    ChatRoom(
      name: 'AI 어시스턴트',
      lastMsg: '@gemma 로 질문해보세요',
      time: '방금',
      unread: 0,
      isAI: true,
      peerId: 'ai-assistant',
    ),
    ChatRoom(
      name: '앨리스',
      lastMsg: '네, 확인해볼게요!',
      time: '3분 전',
      unread: 2,
      isAI: false,
      peerId: 'alice',
    ),
    ChatRoom(
      name: '밥',
      lastMsg: 'Liberty Reach P2P로 연결됨',
      time: '10분 전',
      unread: 0,
      isAI: false,
      peerId: 'bob',
    ),
    ChatRoom(
      name: 'Node 1',
      lastMsg: '/id 로 내 Peer ID 확인',
      time: '1시간 전',
      unread: 0,
      isAI: false,
      peerId: 'node-1',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liberty Reach'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _openChat(context, ChatRoom(
              name: 'AI 어시스턴트',
              lastMsg: '',
              time: '',
              unread: 0,
              isAI: true,
              peerId: 'ai-assistant',
            )),
          ),
        ],
      ),
      body: _rooms.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
              itemBuilder: (context, index) {
                return _ChatRoomTile(
                  room: _rooms[index],
                  onTap: () => _openChat(context, _rooms[index]),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '연결된 대화가 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, ChatRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: room.peerId,
          peerName: room.name,
          isAI: room.isAI,
        ),
      ),
    );
  }
}

class ChatRoom {
  final String name;
  final String lastMsg;
  final String time;
  final int unread;
  final bool isAI;
  final String peerId;

  ChatRoom({
    required this.name,
    required this.lastMsg,
    required this.time,
    required this.unread,
    required this.isAI,
    required this.peerId,
  });
}

class _ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback onTap;

  const _ChatRoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: room.isAI
            ? const Color(0xFFFEE500)
            : Colors.grey[300],
        child: Icon(
          room.isAI ? Icons.auto_awesome : Icons.person,
          color: Colors.black54,
          size: 24,
        ),
      ),
      title: Text(
        room.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          room.lastMsg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(room.time, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          if (room.unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE500),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${room.unread}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
