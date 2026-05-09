import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

class ChatService extends ChangeNotifier {
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final Uuid _uuid = const Uuid();

  Stream<ChatMessage> get messages => _messageController.stream;

  final List<ChatMessage> _messageHistory = [];
  List<ChatMessage> get messageHistory => List.unmodifiable(_messageHistory);

  void send(String text, String peerId) {
    debugPrint('[ChatService] Sending to $peerId: $text');
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
    return msg;
  }

  void markAsRead(String messageId) {
    final idx = _messageHistory.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messageHistory[idx] = _messageHistory[idx].copyWith(isRead: true);
      notifyListeners();
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

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
  }
}
