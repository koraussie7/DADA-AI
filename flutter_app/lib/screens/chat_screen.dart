import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/localai_service.dart';
import '../services/chat_service.dart';
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
  final LocalAIService _ai = LocalAIService();
  final ChatService _chat = ChatService();
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  bool _isAiReady = false;
  bool _isLoading = false;
  StreamSubscription? _chatSub;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _chatSub = _chat.messages.listen((msg) {
      if (mounted) _addMessage(msg);
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _ai.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    final ok = await _ai.health();
    if (mounted) setState(() => _isAiReady = ok);
  }

  void _addMessage(ChatMessage msg) {
    setState(() => _messages.add(msg));
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

  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    final file = await _picker.pickImage(source: src, maxWidth: 1024);
    if (file == null) return;
    await _sendImage(file.path);
  }

  Future<void> _sendImage(String path) async {
    setState(() => _isLoading = true);
    final prompt = _textController.text.trim().isEmpty ? 'Describe this image' : _textController.text.trim();
    _textController.clear();

    final bytes = await File(path).readAsBytes();
    final b64 = base64Encode(bytes);

    _addMessage(ChatMessage(id: _uuid.v4(), sender: 'me', content: prompt, isMe: true, imagePaths: [path]));
    _addMessage(ChatMessage(id: _uuid.v4(), sender: 'Gemma AI', content: 'Analyzing...', isMe: false, isAI: true, isLoading: true));

    final response = await _ai.generateMultimodal(prompt, [b64]);

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.isLoading);
        _addMessage(ChatMessage(id: _uuid.v4(), sender: 'Gemma AI', content: response, isMe: false, isAI: true));
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;
    _textController.clear();

    _addMessage(ChatMessage(id: _uuid.v4(), sender: 'me', content: text, isMe: true));

    if (widget.isAI || text.startsWith('@gemma ') || text.startsWith('@ai ')) {
      final prompt = text.replaceFirst(RegExp(r'^@(gemma|ai)\s'), '');
      await _getAiResponse(prompt);
    } else {
      _chat.send(text, widget.peerId);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _addMessage(ChatMessage(id: _uuid.v4(), sender: widget.peerName, content: 'Reply: "$text"', isMe: false));
      });
    }
  }

  Future<void> _getAiResponse(String prompt) async {
    setState(() => _isLoading = true);
    final lid = _uuid.v4();
    _addMessage(ChatMessage(id: lid, sender: 'Gemma AI', content: '...', isMe: false, isAI: true, isLoading: true));

    final resp = await _ai.generate(prompt);

    if (mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == lid);
        _addMessage(ChatMessage(id: _uuid.v4(), sender: 'Gemma AI', content: resp, isMe: false, isAI: true));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.isAI ? const Color(0xFFFEE500) : Colors.grey[300],
              child: Icon(widget.isAI ? Icons.auto_awesome : Icons.person, color: Colors.black54, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(
                      color: _isAiReady ? const Color(0xFF4CAF50) : Colors.grey[400], shape: BoxShape.circle,
                    )),
                    const SizedBox(width: 4),
                    Text(_isAiReady ? 'Gemma-4 Ready' : 'Offline', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_isAiReady && widget.isAI)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange[50],
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Cannot connect to 185.55.243.225:8081', style: TextStyle(fontSize: 12, color: Colors.orange[800])),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.isAI ? Icons.auto_awesome : Icons.chat, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(widget.isAI ? 'Send text or image' : 'Send a message', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final show = i == 0 || _messages[i].sender != _messages[i - 1].sender;
                      return MessageBubble(message: _messages[i], showSender: show);
                    },
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      padding: EdgeInsets.only(left: 4, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.grey), onPressed: widget.isAI ? _pickImage : null),
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
                  hintText: 'Message...',
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
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey[300] : const Color(0xFFFEE500),
                shape: BoxShape.circle,
              ),
              child: Icon(_isLoading ? Icons.hourglass_top : Icons.send, color: Colors.black87, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
