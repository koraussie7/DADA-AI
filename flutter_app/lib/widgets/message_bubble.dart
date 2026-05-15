import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showSender;

  const MessageBubble({super.key, required this.message, this.showSender = true});

  Color get _myBubbleColor => const Color(0xFFFEE500);
  Color get _myBubbleTextColor => Colors.black87;
  Color get _aiBubbleColor => Colors.white;
  Color get _aiBubbleTextColor => Colors.black87;
  Color get _otherBubbleColor => Colors.white;
  Color get _otherBubbleTextColor => Colors.black87;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // --- Sender Label ---
          if (showSender && !isMe && message.isAI)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3, top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEE500), Color(0xFFFFD54F)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 11, color: Colors.brown),
                    const SizedBox(width: 4),
                    Text(
                      message.sender,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.brown,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (showSender && !isMe && !message.isAI)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2, top: 6),
              child: Text(
                message.sender,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),

          // --- Bubble + Time ---
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) const SizedBox(width: 4),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: message.hasImages ? 6 : 10,
                    bottom: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isAI ? _aiBubbleColor : isMe ? _myBubbleColor : _otherBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Loading indicator
                      if (message.isLoading)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFFFEE500),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '생각 중...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        // Image preview
                        if (message.hasImages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                base64Decode(message.imagePaths.first),
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                              ),
                            ),
                          ),
                        // Text content
                        SelectableText(
                          message.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: message.isAI
                                ? _aiBubbleTextColor
                                : isMe
                                    ? _myBubbleTextColor
                                    : _otherBubbleTextColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Timestamp + read status (only for my messages)
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 13,
                        color: message.isRead
                            ? const Color(0xFFFEE500)
                            : Colors.grey[400],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
