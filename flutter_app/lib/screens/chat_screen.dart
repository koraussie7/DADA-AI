import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

  // 송신자별 마지막 시간 (타임스탬프 구분선용)
  DateTime? _lastTimestamp;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _ai.fetchModels();
    _chatSub = _chat.messages.listen((msg) {
      if (mounted) _addMessage(msg);
    });
    // 시작 메시지 (AI 채팅방)
    if (widget.isAI) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _addMessage(ChatMessage(
            id: _uuid.v4(),
            sender: widget.peerName,
            content: '안녕하세요! 무엇을 도와드릴까요? 😊',
            isMe: false,
            isAI: true,
          ));
        }
      });
    }
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
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
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
    final prompt = _textController.text.trim().isEmpty
        ? 'Describe this image'
        : _textController.text.trim();
    _textController.clear();

    try {
      final bytes = await File(path).readAsBytes();
      final b64 = base64Encode(bytes);

      _addMessage(ChatMessage(
        id: _uuid.v4(),
        sender: 'me',
        content: prompt,
        isMe: true,
        imagePaths: [path],
      ));
      final lid = _uuid.v4();
      _addMessage(ChatMessage(
        id: lid,
        sender: _modelName,
        content: 'Analyzing...',
        isMe: false,
        isAI: true,
        isLoading: true,
      ));

      final response = await _ai.generate(prompt, images: [b64]);

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == lid);
          _addMessage(ChatMessage(
            id: _uuid.v4(),
            sender: _modelName,
            content: response,
            isMe: false,
            isAI: true,
          ));
        });
      }
    } catch (e) {
      debugPrint('[Chat] Image error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.isLoading);
          _addMessage(ChatMessage(
            id: _uuid.v4(),
            sender: _modelName,
            content: 'Error: ${e.toString().length > 100 ? "Request failed" : e.toString()}',
            isMe: false,
            isAI: true,
          ));
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

    if (widget.isAI ||
        text.startsWith('@gemma ') ||
        text.startsWith('@ai ') ||
        text.startsWith('@gemini ') ||
        hadImages) {
      final prompt = text.replaceFirst(RegExp(r'^@(gemma|ai|gemini)\s'), '');
      await _getAiResponse(prompt, images: hadImages ? imagesToSend : null);
    } else {
      try {
        _chat.send(text, widget.peerId);
      } catch (e) {
        debugPrint('[Chat] Send error: $e');
      }
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _addMessage(ChatMessage(
            id: _uuid.v4(),
            sender: widget.peerName,
            content: 'Reply: "$text"',
            isMe: false,
          ));
        }
      });
    }
  }

  Future<void> _getAiResponse(String prompt, {List<String>? images}) async {
    setState(() => _isLoading = true);
    final lid = _uuid.v4();
    _addMessage(ChatMessage(
      id: lid,
      sender: _modelName,
      content: '...',
      isMe: false,
      isAI: true,
      isLoading: true,
    ));

    try {
      final resp = await _ai.generate(prompt, images: images);

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == lid);
          _addMessage(ChatMessage(
            id: _uuid.v4(),
            sender: _modelName,
            content: resp,
            isMe: false,
            isAI: true,
          ));
        });
      }
    } catch (e) {
      debugPrint('[Chat] AI error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == lid);
          _addMessage(ChatMessage(
            id: _uuid.v4(),
            sender: _modelName,
            content: 'Error: ${e.toString().length > 100 ? "Request failed" : e.toString()}',
            isMe: false,
            isAI: true,
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Timestamp divider ---
  Widget _buildDateDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // --- Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient 배경
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8E1), // 상단: 따뜻한 크림색
              Color(0xFFF5F5F5), // 하단: 라이트 그레이
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- Custom AppBar ---
              _buildAppBar(),
              // --- Offline banner ---
              if (!_isAiReady && widget.isAI) _buildOfflineBanner(),
              // --- Message list ---
              Expanded(child: _buildMessageList()),
              // --- Pending images ---
              if (_pendingImages.isNotEmpty) _buildPendingImages(),
              // --- Input area ---
              _buildInput(),
            ],
          ),
        ),
      ),
    );
  }

  // --- Custom AppBar ---
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: widget.isAI
                ? const Color(0xFFFEE500)
                : Colors.grey[300],
            child: Icon(
              widget.isAI ? Icons.auto_awesome : Icons.person,
              color: widget.isAI ? Colors.brown : Colors.black54,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: widget.isAI
                            ? (_isAiReady
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[400])
                            : const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isAI
                          ? (_isAiReady ? 'On • $_modelName' : 'Offline')
                          : 'Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Model selector
          if (widget.isAI)
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune, size: 20, color: Colors.grey),
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
                        color: m.id == _ai.selectedModel
                            ? const Color(0xFFFEE500)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: m.id == _ai.selectedModel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: Colors.black87,
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
    );
  }

  // --- Offline banner ---
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange[50],
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            'AI 서버 연결 안 됨',
            style: TextStyle(fontSize: 12, color: Colors.orange[800]),
          ),
        ],
      ),
    );
  }

  // --- Message list ---
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isAI ? Icons.chat_bubble_outline : Icons.chat_bubble_outline,
              size: 52,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 14),
            Text(
              widget.isAI ? 'AI에게 질문해보세요' : '메시지를 보내보세요',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.isAI) ...[
              const SizedBox(height: 6),
              Text(
                '이미지도 함께 분석됩니다',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final showSender = i == 0 || _messages[i].sender != _messages[i - 1].sender;
        final showDate = i == 0 ||
            _messages[i].timestamp.day != _messages[i - 1].timestamp.day;

        return Column(
          children: [
            if (showDate) _buildDateDivider(),
            MessageBubble(message: msg, showSender: showSender),
          ],
        );
      },
    );
  }

  // --- Pending images ---
  Widget _buildPendingImages() {
    return Container(
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
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(_pendingImages[i]),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _removePendingImage(i),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Input bar ---
  Widget _buildInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 6,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          // Image attach button
          if (widget.isAI)
            PopupMenuButton<String>(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    size: 18, color: Colors.grey),
              ),
              tooltip: 'Add image',
              onSelected: (v) {
                if (v == 'gallery') _pickImage();
                if (v == 'camera') _pickImage();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'gallery',
                  child: ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('갤러리'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'camera',
                  child: ListTile(
                    leading: Icon(Icons.camera_alt),
                    title: Text('카메라'),
                    dense: true,
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: widget.isAI
                      ? '$_modelName에게 질문하기...'
                      : '메시지 입력...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFEE500), Color(0xFFFFD54F)],
                      ),
                color: _isLoading ? Colors.grey[300] : null,
                shape: BoxShape.circle,
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFFEE500).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_top : Icons.send,
                color: _isLoading ? Colors.grey : Colors.brown,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
