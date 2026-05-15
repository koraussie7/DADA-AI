import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'p2p_service.dart';

class ChatService extends ChangeNotifier {
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final Uuid _uuid = const Uuid();
  P2PService? _p2p;

  Stream<ChatMessage> get messages => _messageController.stream;

  final List<ChatMessage> _messageHistory = [];
  List<ChatMessage> get messageHistory => List.unmodifiable(_messageHistory);

  void attachP2P(P2PService p2p) {
    _p2p = p2p;
    p2p.incoming.listen((msg) {
      final chatMsg = ChatMessage(
        id: _uuid.v4(),
        sender: msg.sender,
        content: msg.content,
        isMe: false,
        timestamp: DateTime.tryParse(msg.timestamp) ?? DateTime.now(),
      );
      _messageHistory.add(chatMsg);
      _messageController.add(chatMsg);
      notifyListeners();
      _persist();
    });
  }

  void send(String text, String peerId) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      sender: 'me',
      content: text,
      isMe: true,
    );
    _messageHistory.add(msg);
    _messageController.add(msg);
    notifyListeners();

    if (_p2p != null && _p2p!.isConnected) {
      if (peerId == 'all') {
        _p2p!.broadcast(text);
      } else {
        _p2p!.sendMessage(peerId, text);
      }
    }

    _persist();
  }

  ChatMessage receiveMessage({
    required String sender,
    required String content,
    bool isAI = false,
  }) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      sender: sender,
      content: content,
      isMe: false,
      isAI: isAI,
      isRead: false,
    );
    _messageHistory.add(msg);
    _messageController.add(msg);
    notifyListeners();
    _persist();
    return msg;
  }

  void markAsRead(String messageId) {
    final idx = _messageHistory.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messageHistory[idx] = _messageHistory[idx].copyWith(isRead: true);
      notifyListeners();
      _persist();
    }
  }

  String encodeMessage(ChatMessage msg) {
    return jsonEncode(msg.toJson());
  }

  ChatMessage? decodeMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ChatMessage.fromJson(data);
    } catch (e) {
      debugPrint('Failed to decode message: $e');
      return null;
    }
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_history_v2');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _messageHistory.clear();
      for (final e in list) {
        _messageHistory.add(ChatMessage.fromJson(e as Map<String, dynamic>));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Chat] loadHistory error: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = _messageHistory.length > 200
        ? _messageHistory.sublist(_messageHistory.length - 200)
        : _messageHistory;
    final raw = jsonEncode(recent.map((m) => m.toJson()).toList());
    await prefs.setString('chat_history_v2', raw);
  }

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
  }
}
