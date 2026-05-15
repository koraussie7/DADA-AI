import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showSender;

  const MessageBubble({super.key, required this.message, this.showSender = true});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // --- Sender label (AI only) ---
          if (showSender && !isMe && message.isAI)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4, top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0xFFFEE500),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 11, color: Colors.brown[700]),
                    const SizedBox(width: 4),
                    Text(
                      message.sender,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.brown[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (showSender && !isMe && !message.isAI)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2, top: 6),
              child: Text(
                message.sender,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),

          // --- Content (NO background, black text) ---
          if (message.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFEE500)),
                  ),
                  SizedBox(width: 8),
                  Text('생각 중...', style: TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            )
          else ...[
            if (message.hasImages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(message.imagePaths.first),
                    width: 200, height: 200, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                  ),
                ),
              ),
            // PURE TEXT - transparent bg, black color
            SelectableText(
              message.content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black,
              ),
            ),
          ],
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}
