import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final Uuid _uuid = const Uuid();

  ChatBloc() : super(const ChatState()) {
    on<SendMessageEvent>(_onSendMessage);
    on<ReceiveMessageEvent>(_onReceiveMessage);
    on<LoadMessagesEvent>(_onLoadMessages);
  }

  Future<void> _onSendMessage(SendMessageEvent event, Emitter<ChatState> emit) async {
    final message = Message(
      id: _uuid.v4(),
      content: event.content,
      senderId: event.senderId,
      senderName: event.senderName,
    );
    emit(state.copyWith(
      messages: [...state.messages, message],
    ));
  }

  void _onReceiveMessage(ReceiveMessageEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(
      messages: [...state.messages, event.message],
    ));
  }

  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      // TODO: load from P2P service / local storage
      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
