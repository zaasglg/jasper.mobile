import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../domain/repositories/chat_repository.dart';

class ConversationState extends Equatable {
  const ConversationState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  @override
  List<Object?> get props => [messages, isLoading, isSending, error];

  ConversationState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) => ConversationState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    error: clearError ? null : error ?? this.error,
  );
}

class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(this._repository, this.conversation)
    : super(const ConversationState());
  final ChatRepository _repository;
  final ChatConversationModel conversation;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      emit(
        state.copyWith(
          messages: await _repository.getMessages(conversation.threadId),
          isLoading: false,
        ),
      );
    } on ChatException catch (error) {
      emit(state.copyWith(isLoading: false, error: error.message));
    }
  }

  Future<bool> sendVoice(String dataUrl, int duration) async {
    if (state.isSending || !dataUrl.startsWith('data:audio/')) return false;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final message = await _repository.sendMessage(
        conversation: conversation,
        text: '',
        kind: ChatMessageKind.audio,
        transcript: dataUrl,
        duration: duration,
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          messages: [...state.messages, message],
          isSending: false,
        ),
      );
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSending: false,
            error: error is ChatException
                ? error.message
                : 'Не удалось отправить запись. Повторите отправку.',
          ),
        );
      }
      return false;
    }
  }

  Future<bool> sendAttachment({
    required String text,
    required String dataUrl,
    int? duration,
  }) async {
    if (state.isSending || !dataUrl.startsWith('data:')) return false;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final message = await _repository.sendMessage(
        conversation: conversation,
        text: text,
        kind: ChatMessageKind.text,
        mention: dataUrl,
        duration: duration,
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          messages: [...state.messages, message],
          isSending: false,
        ),
      );
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isSending: false,
            error: error is ChatException
                ? error.message
                : 'Не удалось отправить вложение. Повторите отправку.',
          ),
        );
      }
      return false;
    }
  }

  Future<bool> send(String text) async {
    if (text.trim().isEmpty || state.isSending) return false;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final message = await _repository.sendMessage(
        conversation: conversation,
        text: text.trim(),
      );
      emit(
        state.copyWith(
          messages: [...state.messages, message],
          isSending: false,
        ),
      );
      return true;
    } on ChatException catch (error) {
      emit(state.copyWith(isSending: false, error: error.message));
      return false;
    }
  }
}
