import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'p2p_service.dart';
import 'chat_service.dart';

class LibertyBridge extends ChangeNotifier {
  final P2PService _p2p;
  final ChatService _chat;
  final Uuid _uuid = const Uuid();
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();

  bool _initialized = false;
  String? _peerId;
  StreamSubscription? _incomingSubscription;

  Stream<ChatMessage> get onMessage => _messageController.stream;
  String? get peerId => _peerId;
  bool get isInitialized => _initialized;

  LibertyBridge(this._p2p, this._chat);

  Future<String> init({
    required String peerName,
    String serverUrl = 'https://privseai.com',
  }) async {
    try {
      _peerId = '12D3KooW${peerName.hashCode.toString().padLeft(8, '0')}';
      _p2p.setLocalPeerId(_peerId!);

      _incomingSubscription?.cancel();
      _incomingSubscription = _p2p.incoming.listen((msg) {
        final chatMsg = ChatMessage(
          id: _uuid.v4(),
          sender: msg.sender,
          content: msg.content,
          isMe: false,
          isAI: false,
          timestamp: DateTime.tryParse(msg.timestamp) ?? DateTime.now(),
        );
        _chat.receiveMessage(
          sender: msg.sender,
          content: msg.content,
        );
        _messageController.add(chatMsg);
      });

      _initialized = true;
      notifyListeners();
      return 'Initialized as $peerName';
    } catch (e) {
      return 'Init error: $e';
    }
  }

  Future<void> connectToServer(String serverUrl) async {
    await _p2p.connect(serverUrl);
  }

  Future<String> sendMessage(String content) async {
    _chat.send(content, _peerId ?? 'all');
    return content;
  }

  Future<String> askAI(String prompt) async {
    debugPrint('[LibertyBridge] AI ask: $prompt');
    return '(AI response for: $prompt)';
  }

  Future<String> askMultimodal(String prompt, List<String> imagesBase64) async {
    debugPrint('[LibertyBridge] Multimodal ask: $prompt (${imagesBase64.length} images)');
    return '(AI multimodal response for: $prompt)';
  }

  Future<String> connectToPeer(String address) async {
    return 'connecting to $address';
  }

  Future<bool> checkAIHealth() async {
    return true;
  }

  Future<List<ChatMessage>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_history');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[LibertyBridge] history decode error: $e');
      return [];
    }
  }

  Future<void> saveHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = messages.length > 200 ? messages.sublist(messages.length - 200) : messages;
    final raw = jsonEncode(recent.map((m) => m.toJson()).toList());
    await prefs.setString('chat_history', raw);
  }

  void incomingMessage(ChatMessage msg) {
    _messageController.add(msg);
  }

  @override
  void dispose() {
    _incomingSubscription?.cancel();
    _messageController.close();
    super.dispose();
  }
}
