import 'package:flutter_test/flutter_test.dart';
import 'package:liberty_reach/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('should create a message with default values', () {
      final msg = ChatMessage(
        id: 'test-1',
        sender: 'me',
        content: 'Hello',
        isMe: true,
      );

      expect(msg.id, 'test-1');
      expect(msg.sender, 'me');
      expect(msg.content, 'Hello');
      expect(msg.isMe, true);
      expect(msg.isAI, false);
      expect(msg.isLoading, false);
      expect(msg.isRead, false);
    });

    test('should serialize and deserialize to JSON', () {
      final original = ChatMessage(
        id: 'test-2',
        sender: 'Alice',
        content: 'Hi there!',
        isMe: false,
        isAI: false,
        isRead: true,
        timestamp: DateTime(2026, 5, 9, 12, 0, 0),
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.sender, original.sender);
      expect(restored.content, original.content);
      expect(restored.isMe, original.isMe);
      expect(restored.isAI, original.isAI);
      expect(restored.isRead, original.isRead);
      expect(restored.timestamp, original.timestamp);
    });

    test('copyWith should create a modified copy', () {
      final original = ChatMessage(
        id: 'test-3',
        sender: 'me',
        content: 'Original',
        isMe: true,
      );

      final modified = original.copyWith(
        content: 'Modified',
        isRead: true,
      );

      expect(modified.id, original.id);
      expect(modified.content, 'Modified');
      expect(modified.isRead, true);
      expect(modified.isMe, true);
    });
  });
}
