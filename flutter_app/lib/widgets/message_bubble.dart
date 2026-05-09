import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showSender;

  const MessageBubble({
    super.key,
    required this.message,
    this.showSender = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && !isMe && message.isAI)
            _buildSenderLabel(),
          if (showSender && !isMe && !message.isAI && message.sender != 'System')
            _buildPlainSenderLabel(),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _bubbleColor(isMe),
                    borderRadius: _bubbleRadius(isMe),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: message.isLoading
                      ? _buildLoadingIndicator()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.isAI)
                              _buildAiBadge(),
                            if (message.isAI) const SizedBox(height: 4),
                            SelectableText(
                              message.content,
                              style: TextStyle(
                                fontSize: 15,
                                color: isMe ? Colors.black87 : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildTimeAndRead(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSenderLabel() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 10, color: Color(0xFF8B7E00)),
                SizedBox(width: 3),
                Text(
                  'Gemma AI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B7E00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainSenderLabel() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2, top: 4),
      child: Text(
        message.sender,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildAiBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE500).withOpacity(0.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B5E00),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFEE500),
          ),
        ),
        SizedBox(width: 8),
        Text(
          'AI가 답변을 준비 중...',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTimeAndRead() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('HH:mm').format(message.timestamp),
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
        const SizedBox(height: 2),
        Icon(
          message.isRead ? Icons.done_all : Icons.done,
          size: 14,
          color: message.isRead
              ? const Color(0xFFFEE500)
              : Colors.grey[400],
        ),
      ],
    );
  }

  Color _bubbleColor(bool isMe) {
    if (message.isLoading) return Colors.grey[100]!;
    if (message.isAI) return Colors.grey[100]!;
    return isMe ? const Color(0xFFFEE500) : Colors.white;
  }

  BorderRadius _bubbleRadius(bool isMe) {
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );
  }
}
