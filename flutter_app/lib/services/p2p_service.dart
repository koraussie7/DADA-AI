import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class P2PMessage {
  final String type;
  final String sender;
  final String content;
  final String timestamp;

  P2PMessage({
    required this.type,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  factory P2PMessage.fromJson(Map<String, dynamic> json) => P2PMessage(
        type: json['type'] as String? ?? 'chat',
        sender: json['sender'] as String? ?? 'unknown',
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'sender': sender,
        'content': content,
        'timestamp': timestamp,
      };
}

class P2PService extends ChangeNotifier {
  final StreamController<P2PMessage> _incoming =
      StreamController<P2PMessage>.broadcast();

  Stream<P2PMessage> get incoming => _incoming.stream;

  String? _localPeerId;
  String? get localPeerId => _localPeerId;

  final List<String> _peers = [];
  List<String> get connectedPeers => List.unmodifiable(_peers);

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void onMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _incoming.add(P2PMessage.fromJson(data));
    } catch (e) {
      debugPrint('P2P parse error: $e');
    }
  }

  void peerConnected(String peerId) {
    if (!_peers.contains(peerId)) {
      _peers.add(peerId);
      _isConnected = true;
      notifyListeners();
    }
  }

  void peerDisconnected(String peerId) {
    _peers.remove(peerId);
    _isConnected = _peers.isNotEmpty;
    notifyListeners();
  }

  void setLocalPeerId(String id) {
    _localPeerId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    _incoming.close();
    super.dispose();
  }
}
