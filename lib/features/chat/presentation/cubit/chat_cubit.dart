import 'dart:async';
import 'package:equatable/equatable.dart';
import '../../data/chat_list_changes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/chat_conversation_model.dart';
import '../../domain/repositories/chat_repository.dart';

sealed class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  const ChatLoaded(this.conversations, {this.isCreating = false});
  final List<ChatConversationModel> conversations;
  final bool isCreating;
  @override
  List<Object?> get props => [conversations, isCreating];
}

class ChatFailure extends ChatState {
  const ChatFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repository) : super(const ChatLoading()) {
    chatListChanges.addListener(_changed);
  }
  Timer? _timer;
  bool _active = false, _loading = false, _pending = false;
  int _revision = 0;
  void _changed() {
    if (_active) unawaited(load(silent: true));
  }

  void setAutoRefresh(bool active) {
    if (_active == active) return;
    _active = active;
    _timer?.cancel();
    if (active) {
      unawaited(load(silent: true));
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _changed());
    }
  }

  void invalidate() {
    _revision++;
    _pending = false;
    if (!isClosed) emit(const ChatLoading());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    chatListChanges.removeListener(_changed);
    _revision++;
    return super.close();
  }

  final ChatRepository _repository;
  ChatRepository get repository => _repository;

  Future<void> load({bool silent = false}) async {
    if (isClosed) return;
    if (_loading || (state is ChatLoaded && (state as ChatLoaded).isCreating)) {
      _pending = true;
      return;
    }
    _loading = true;
    final revision = _revision;
    final hadData = state is ChatLoaded;
    if (!silent || !hadData) emit(const ChatLoading());
    try {
      final conversations = await _repository.getConversations();
      if (!isClosed && revision == _revision) emit(ChatLoaded(conversations));
    } catch (error) {
      if (!isClosed && revision == _revision && !(silent && hadData)) {
        emit(
          ChatFailure(
            error is ChatException
                ? error.message
                : 'Не удалось загрузить чаты.',
          ),
        );
      }
    } finally {
      _loading = false;
      if (_pending && !isClosed) {
        _pending = false;
        if (_active) unawaited(load(silent: true));
      }
    }
  }

  Future<bool> createChannel(String name, {String? parentId}) async {
    final current = state;
    if (current is! ChatLoaded || current.isCreating || name.trim().isEmpty) {
      return false;
    }
    _revision++;
    final revision = _revision;
    emit(ChatLoaded(current.conversations, isCreating: true));
    try {
      final channel = await _repository.createChannel(
        name: name,
        parentId: parentId,
      );
      if (isClosed || revision != _revision) return false;
      emit(ChatLoaded([...current.conversations, channel]));
      notifyChatListChanges();
      return true;
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(ChatLoaded(current.conversations));
      }
      return false;
    }
  }
}
