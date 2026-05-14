part of 'chat_bloc.dart';

class Message extends Equatable {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isAI;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    DateTime? timestamp,
    this.isAI = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.hermes(String content) => Message(
    id: 'hermes_${DateTime.now().millisecondsSinceEpoch}',
    content: content,
    senderId: 'hermes_ai',
    senderName: 'Hermes AI',
    isAI: true,
  );

  @override
  List<Object?> get props => [id, content, senderId, senderName, timestamp, isAI];
}

class ChatState extends Equatable {
  final List<Message> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [messages, isLoading, error];
}
