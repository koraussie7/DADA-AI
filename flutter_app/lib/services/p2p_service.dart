import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants/app_constants.dart';

class P2PMessage {
  final String type;
  final String sender;
  final String content;
  final String timestamp;
  final String? room;

  P2PMessage({
    required this.type,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.room,
  });

  factory P2PMessage.fromJson(Map<String, dynamic> json) => P2PMessage(
    type: json['type'] as String? ?? 'chat',
    sender: json['sender'] as String? ?? 'unknown',
    content: json['content'] as String? ?? '',
    timestamp: json['timestamp'] as String? ?? '',
    room: json['room'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'sender': sender,
    'content': content,
    'timestamp': timestamp,
    if (room != null) 'room': room,
  };
}

class P2PService extends ChangeNotifier {
  final StreamController<P2PMessage> _incoming =
      StreamController<P2PMessage>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _serverUrl;
  bool _disposed = false;

  Stream<P2PMessage> get incoming => _incoming.stream;

  String? _localPeerId;
  String? get localPeerId => _localPeerId;

  final List<String> _peers = [];
  List<String> get connectedPeers => List.unmodifiable(_peers);

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  Future<void> connect(String serverUrl) async {
    if (AppConstants.isLocalDev) {
      debugPrint('[P2P] Local dev — skipping WebSocket');
      _isConnecting = false;
      notifyListeners();
      return;
    }
    _serverUrl = serverUrl;
    _isConnecting = true;
    notifyListeners();

    _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;

    try {
      final peerId = 'peer_${_randomId()}';
      final wsUrl = serverUrl.replaceAll('http://', 'ws://')
          .replaceAll('https://', 'wss://');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/$peerId'));
      _localPeerId = peerId;

      _wsSub = _channel!.stream.listen(
            (data) {
          if (_disposed) return;
          try {
            final raw = data as String;
            final json = jsonDecode(raw) as Map<String, dynamic>;
            final type = json['type'] as String? ?? 'message';

            if (type == 'peer_joined') {
              final peer = json['peer_id'] as String?;
              if (peer != null && peer != _localPeerId) {
                _addPeer(peer);
              }
            } else if (type == 'peer_left') {
              final peer = json['peer_id'] as String?;
              if (peer != null) {
                _removePeer(peer);
              }
            } else if (type == 'pong') {
              // keep-alive received
            } else {
              _incoming.add(P2PMessage.fromJson(json));
            }
          } catch (e) {
            debugPrint('[P2P] parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('[P2P] WS error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[P2P] WS closed');
          _isConnected = false;
          _scheduleReconnect();
          notifyListeners();
        },
      );

      _channel!.sink.add(jsonEncode({
        'type': 'join',
        'peer_id': _localPeerId,
      }));

      _isConnected = true;
      _isConnecting = false;
      _startPing();
      notifyListeners();
    } catch (e) {
      debugPrint('[P2P] connect error: $e');
      _isConnecting = false;
      _scheduleReconnect();
      notifyListeners();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null && _isConnected) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed && _serverUrl != null) {
        debugPrint('[P2P] reconnecting...');
        connect(_serverUrl!);
      }
    });
  }

  String _randomId() {
    final r = Random();
    return r.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  }

  void _addPeer(String peerId) {
    if (!_peers.contains(peerId)) {
      _peers.add(peerId);
      _isConnected = true;
      notifyListeners();
    }
  }

  void _removePeer(String peerId) {
    _peers.remove(peerId);
    _isConnected = _peers.isNotEmpty;
    notifyListeners();
  }

  void sendMessage(String peerId, String content, {String? room}) {
    if (_channel == null || !_isConnected) return;
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'chat',
        'target': peerId,
        'sender': _localPeerId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        if (room != null) 'room': room,
      }));
    } catch (e) {
      debugPrint('[P2P] send error: $e');
    }
  }

  void broadcast(String content, {String? room}) {
    if (_channel == null || !_isConnected) return;
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'chat',
        'target': '*',
        'sender': _localPeerId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        if (room != null) 'room': room,
      }));
    } catch (e) {
      debugPrint('[P2P] broadcast error: $e');
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _peers.clear();
    _localPeerId = null;
    notifyListeners();
  }

  void setLocalPeerId(String id) {
    _localPeerId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    _incoming.close();
    super.dispose();
  }
}
