import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/chat_conversation_model.dart';
import '../../domain/repositories/chat_repository.dart';

sealed class ChatState {
  const ChatState();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  const ChatLoaded(this.conversations, {this.isCreating = false});
  final List<ChatConversationModel> conversations;
  final bool isCreating;
}

class ChatFailure extends ChatState {
  const ChatFailure(this.message);
  final String message;
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repository) : super(const ChatLoading());
  final ChatRepository _repository;

  Future<void> load() async {
    emit(const ChatLoading());
    try {
      emit(ChatLoaded(await _repository.getConversations()));
    } on ChatException catch (error) {
      emit(ChatFailure(error.message));
    } catch (_) {
      emit(const ChatFailure('Не удалось загрузить чаты.'));
    }
  }

  Future<bool> createChannel(String name, {String? parentId}) async {
    final current = state;
    if (current is! ChatLoaded || current.isCreating || name.trim().isEmpty) {
      return false;
    }
    emit(ChatLoaded(current.conversations, isCreating: true));
    try {
      final channel = await _repository.createChannel(
        name: name,
        parentId: parentId,
      );
      emit(ChatLoaded([...current.conversations, channel]));
      return true;
    } on ChatException {
      emit(ChatLoaded(current.conversations));
      return false;
    }
  }
}
