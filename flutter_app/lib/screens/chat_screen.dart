import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/liberty_bridge.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final bool isAI;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.isAI = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final LibertyBridge _bridge = LibertyBridge();
  final Uuid _uuid = const Uuid();

  bool _isAiReady = false;
  bool _isLoading = false;
  StreamSubscription? _bridgeSub;

  @override
  void initState() {
    super.initState();
    _checkAiHealth();
    _listenToBridge();
  }

  @override
  void dispose() {
    _bridgeSub?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _bridge.dispose();
    super.dispose();
  }

  Future<void> _checkAiHealth() async {
    final health = await _bridge.checkAIHealth();
    if (mounted) setState(() => _isAiReady = health);
  }

  void _listenToBridge() {
    _bridgeSub = _bridge.onMessage.listen((msg) {
      if (mounted) _insertMessage(msg);
    });
  }

  void _insertMessage(ChatMessage msg) {
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;
    _textController.clear();

    final isAiCommand = text.startsWith('@gemma ') || text.startsWith('@ai ');

    final myMsg = ChatMessage(
      id: _uuid.v4(),
      sender: 'me',
      content: text,
      isMe: true,
    );
    _insertMessage(myMsg);

    if (widget.isAI || isAiCommand) {
      final prompt = isAiCommand
          ? text.replaceFirst(RegExp(r'^@(gemma|ai)\s'), '')
          : text;
      await _getAiResponse(prompt);
    } else {
      // Send via Rust P2P bridge
      await _bridge.sendMessage(text);
      // Simulate reply for now
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _bridge.incomingMessage(ChatMessage(
            id: _uuid.v4(),
            sender: widget.peerName,
            content: 'Reply from ${widget.peerName}: "$text"',
            isMe: false,
          ));
        }
      });
    }
  }

  Future<void> _getAiResponse(String prompt) async {
    setState(() => _isLoading = true);

    final loadingId = _uuid.v4();
    _insertMessage(ChatMessage(
      id: loadingId,
      sender: 'Gemma AI',
      content: '● ● ●',
      isMe: false,
      isAI: true,
      isLoading: true,
    ));

    final response = await _bridge.askAI(prompt);

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == loadingId);
        _insertMessage(ChatMessage(
          id: _uuid.v4(),
          sender: 'Gemma AI',
          content: response,
          isMe: false,
          isAI: true,
        ));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (!_isAiReady && widget.isAI) _buildAiOfflineBanner(),
          Expanded(
            child: _messages.isEmpty ? _buildEmptyChat() : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final showSender = index == 0 ||
            _messages[index].sender != _messages[index - 1].sender;
        return MessageBubble(
          message: _messages[index],
          showSender: showSender,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: widget.isAI
                ? const Color(0xFFFEE500)
                : Colors.grey[300],
            child: Icon(
              widget.isAI ? Icons.auto_awesome : Icons.person,
              color: Colors.black54,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.peerName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _isAiReady ? const Color(0xFF4CAF50) : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isAiReady ? 'AI 연결됨' : 'AI 오프라인',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange[50],
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text('LocalAI 서버에 연결할 수 없습니다 (localhost:8080)',
              style: TextStyle(fontSize: 12, color: Colors.orange[800])),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.isAI ? Icons.auto_awesome : Icons.chat,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            widget.isAI ? '@gemma 로 AI에게 질문해보세요' : '메시지를 보내보세요',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.grey), onPressed: () {}),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: '메시지 입력...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey[300] : const Color(0xFFFEE500),
                shape: BoxShape.circle,
              ),
              child: Icon(_isLoading ? Icons.hourglass_top : Icons.send,
                  color: Colors.black87, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
