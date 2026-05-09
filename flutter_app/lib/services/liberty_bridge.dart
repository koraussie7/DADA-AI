import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

/// Bridge between Flutter and Rust Liberty Reach core.
///
/// After running `flutter_rust_bridge_codegen generate`, this service
/// will call the generated Dart bindings from `lib/src/rust/`.
///
/// Until then, it uses a simulated backend for development.
class LibertyBridge extends ChangeNotifier {
  bool _initialized = false;
  String? _peerId;
  final List<String> _peers = [];
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  Timer? _simulationTimer;

  Stream<ChatMessage> get onMessage => _messageController.stream;
  String? get peerId => _peerId;
  List<String> get connectedPeers => List.unmodifiable(_peers);
  bool get isInitialized => _initialized;

  Future<String> init({
    required String peerName,
    String localaiUrl = 'http://localhost:8080',
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final storagePath = '${dir.path}/$peerName.db';

      // TODO: Call Rust init() via flutter_rust_bridge:
      // final result = await rust.api.init(
      //   peerName: peerName,
      //   localaiUrl: localaiUrl,
      //   storagePath: storagePath,
      // );

      // Simulated init:
      _peerId = '12D3KooW${peerName.hashCode.toString().padLeft(8, '0')}';
      _initialized = true;
      debugPrint('[LibertyBridge] Initialized: $_peerId');
      notifyListeners();
      _startSimulation();
      return 'Initialized as $peerName (simulated mode)';
    } catch (e) {
      return 'Init error: $e';
    }
  }

  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_peers.isEmpty) {
        _peers.add('12D3KooWSimPeer1');
        _peers.add('12D3KooWSimPeer2');
        notifyListeners();
      }
    });
  }

  Future<String> sendMessage(String content) async {
    // TODO: call Rust send_message()
    // final result = await rust.api.sendMessage(content: content);
    debugPrint('[LibertyBridge] Sending: $content');
    return content;
  }

  Future<String> askAI(String prompt) async {
    // TODO: call Rust ask_ai()
    // final result = await rust.api.askAi(prompt: prompt);
    debugPrint('[LibertyBridge] AI ask: $prompt');
    return '(simulated AI response for: $prompt)';
  }

  Future<String> connectToPeer(String address) async {
    // TODO: call Rust connect_to_peer()
    // final result = await rust.api.connectToPeer(address: address);
    if (!_peers.contains(address)) {
      _peers.add(address);
      notifyListeners();
    }
    return 'connecting to $address (simulated)';
  }

  Future<bool> checkAIHealth() async {
    // TODO: call Rust check_ai_health()
    // final result = await rust.api.checkAiHealth();
    return true;
  }

  Future<List<ChatMessage>> getHistory() async {
    // TODO: call Rust get_message_history()
    // final entries = await rust.api.getMessageHistory(limit: 50);
    return [];
  }

  void incomingMessage(ChatMessage msg) {
    _messageController.add(msg);
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _messageController.close();
    super.dispose();
  }
}
