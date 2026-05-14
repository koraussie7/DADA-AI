part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class SendMessageEvent extends ChatEvent {
  final String content;
  final String groupId;
  final String senderId;
  final String senderName;

  const SendMessageEvent({
    required this.content,
    required this.groupId,
    this.senderId = 'current_user',
    this.senderName = 'Me',
  });

  @override
  List<Object?> get props => [content, groupId, senderId, senderName];
}

class ReceiveMessageEvent extends ChatEvent {
  final Message message;

  const ReceiveMessageEvent({required this.message});

  @override
  List<Object?> get props => [message];
}

class LoadMessagesEvent extends ChatEvent {
  final String groupId;

  const LoadMessagesEvent({required this.groupId});

  @override
  List<Object?> get props => [groupId];
}
