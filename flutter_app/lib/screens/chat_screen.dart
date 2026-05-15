import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final Uuid _uuid = const Uuid();
  final ImagePicker _picker = ImagePicker();

  bool _isAiReady = false;
  bool _isLoading = false;
  List<String> _pendingImages = [];
  StreamSubscription? _chatSub;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _ai.fetchModels();
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

  String get _modelName {
    final m = _ai.selectedModel;
    if (m.startsWith('gemini')) return 'Gemini';
    return m;
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
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final b64 = base64Encode(bytes);
      if (mounted) {
        setState(() => _pendingImages.add(b64));
      }
    }
  }

  Future<void> _sendImage(String path) async {
    setState(() => _isLoading = true);
    final prompt = _textController.text.trim().isEmpty ? 'Describe this image' : _textController.text.trim();
    _textController.clear();

    try {
      final bytes = await File(path).readAsBytes();
      final b64 = base64Encode(bytes);

      _addMessage(ChatMessage(id: _uuid.v4(), sender: 'me', content: prompt, isMe: true, imagePaths: [path]));
      final lid = _uuid.v4();
      _addMessage(ChatMessage(id: lid, sender: 'Gemma AI', content: 'Analyzing...', isMe: false, isAI: true, isLoading: true));

      final response = await _ai.generate(prompt, images: [b64]);

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == lid);
          _addMessage(ChatMessage(id: _uuid.v4(), sender: 'Gemma AI', content: response, isMe: false, isAI: true));
        });
      }
    } catch (e) {
      debugPrint('[Chat] Image error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.isLoading);
          _addMessage(ChatMessage(id: _uuid.v4(), sender: 'Gemma AI', content: 'Error: ${e.toString().length > 100 ? "Request failed" : e.toString()}', isMe: false, isAI: true));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if ((text.isEmpty && _pendingImages.isEmpty) || _isLoading) return;
    _textController.clear();

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      sender: 'me',
      content: text,
      isMe: true,
      imagePaths: List.from(_pendingImages),
    );
    _addMessage(userMsg);

    final hadImages = _pendingImages.isNotEmpty;
    final imagesToSend = List<String>.from(_pendingImages);
    setState(() => _pendingImages = []);

    if (widget.isAI || text.startsWith('@gemma ') || text.startsWith('@ai ') || text.startsWith('@gemini ') || hadImages) {
      final prompt = text.replaceFirst(RegExp(r'^@(gemma|ai|gemini)\s'), '');
      await _getAiResponse(prompt, images: hadImages ? imagesToSend : null);
    } else {
      try {
        _chat.send(text, widget.peerId);
      } catch (e) {
        debugPrint('[Chat] Send error: $e');
      }
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _addMessage(ChatMessage(id: _uuid.v4(), sender: widget.peerName, content: 'Reply: "$text"', isMe: false));
      });
    }
  }

  Future<void> _getAiResponse(String prompt, {List<String>? images}) async {
    setState(() => _isLoading = true);
    final lid = _uuid.v4();
    _addMessage(ChatMessage(id: lid, sender: _modelName, content: '...', isMe: false, isAI: true, isLoading: true));

    try {
      final resp = await _ai.generate(prompt, images: images);

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == lid);
          _addMessage(ChatMessage(id: _uuid.v4(), sender: _modelName, content: resp, isMe: false, isAI: true));
        });
      }
    } catch (e) {
      debugPrint('[Chat] AI error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == lid);
          _addMessage(ChatMessage(id: _uuid.v4(), sender: 'Gemma AI', content: 'Error: ${e.toString().length > 100 ? "Request failed" : e.toString()}', isMe: false, isAI: true));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.peerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(
                        color: _isAiReady ? const Color(0xFF4CAF50) : Colors.grey[400], shape: BoxShape.circle,
                      )),
                      const SizedBox(width: 4),
                      Text(_isAiReady ? '$_modelName Ready' : 'Offline', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.isAI)
              PopupMenuButton<String>(
                icon: const Icon(Icons.model_training, size: 20, color: Colors.black54),
                tooltip: 'Select model',
                onSelected: (m) {
                  _ai.selectModel(m);
                  setState(() {});
                },
                itemBuilder: (ctx) => _ai.availableModels.map((m) {
                  return PopupMenuItem(
                    value: m.id,
                    child: Row(
                      children: [
                        Icon(
                          m.isGemini ? Icons.auto_awesome : Icons.memory,
                          size: 16,
                          color: m.id == _ai.selectedModel ? const Color(0xFFFEE500) : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: m.id == _ai.selectedModel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (m.id == _ai.selectedModel)
                          const Icon(Icons.check, size: 14, color: Color(0xFFFEE500)),
                      ],
                    ),
                  );
                }).toList(),
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
                  Text('AI server offline', style: TextStyle(fontSize: 12, color: Colors.orange[800])),
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
                        Text('Send a message', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                        if (widget.isAI) ...[
                          const SizedBox(height: 4),
                          Text('Images are analyzed with $_modelName', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        ],
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
          if (_pendingImages.isNotEmpty)
            Container(
              height: 80,
              color: Colors.grey[50],
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _pendingImages.length,
                itemBuilder: (_, i) => Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(_pendingImages[i]),
                          width: 64, height: 64, fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => _removePendingImage(i),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
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
          if (widget.isAI)
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
              tooltip: 'Add image',
              onSelected: (v) {
                if (v == 'gallery') _pickImage();
                if (v == 'camera') _pickImage(); // camera via browser
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'gallery', child: ListTile(leading: Icon(Icons.photo_library), title: Text('Gallery'), dense: true)),
                const PopupMenuItem(value: 'camera', child: ListTile(leading: Icon(Icons.camera_alt), title: Text('Camera'), dense: true)),
              ],
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: widget.isAI ? 'Ask $_modelName...' : 'Message...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
