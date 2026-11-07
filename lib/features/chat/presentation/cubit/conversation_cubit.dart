import 'dart:async';
import '../../data/thread_typing_controller.dart';
import '../../data/models/chat_interaction_models.dart';
import '../../data/chat_list_changes.dart';
import '../../../calls/data/call_message_changes.dart';
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
    this.replyTo,
    this.typingUsers = const [],
  });
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final ChatMessageModel? replyTo;
  final List<ChatTypingUser> typingUsers;

  @override
  List<Object?> get props => [
    messages,
    isLoading,
    isSending,
    error,
    replyTo,
    typingUsers,
  ];

  ConversationState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
    ChatMessageModel? replyTo,
    bool clearReply = false,
    List<ChatTypingUser>? typingUsers,
  }) => ConversationState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    error: clearError ? null : error ?? this.error,
    replyTo: clearReply ? null : replyTo ?? this.replyTo,
    typingUsers: typingUsers ?? this.typingUsers,
  );
}

class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit(this._repository, this.conversation)
    : super(const ConversationState()) {
    callMessageChanges.addListener(_onCallChange);
    if (_repository is ChatInteractionRepository) {
      _typing = ThreadTypingController(
        _repository as ChatInteractionRepository,
        conversation.threadId,
      )..addListener(_onTyping);
    }
  }
  ThreadTypingController? _typing;
  void _onTyping() {
    if (!isClosed && !_invalidated) {
      emit(state.copyWith(typingUsers: _typing!.users));
    }
  }

  void notifyTyping(String text) => _typing?.textChanged(text);
  void stopTyping() => _typing?.stop();
  void selectReply(ChatMessageModel? message) {
    if (!_invalidated && !isClosed) {
      emit(state.copyWith(replyTo: message, clearReply: message == null));
    }
  }

  void _onCallChange() {
    if (!isClosed && _active) unawaited(load(silent: true));
  }

  @override
  Future<void> close() {
    _typing?.removeListener(_onTyping);
    _typing?.dispose();
    _timer?.cancel();
    _revision++;
    callMessageChanges.removeListener(_onCallChange);
    return super.close();
  }

  final ChatRepository _repository;
  final ChatConversationModel conversation;

  Timer? _timer;
  bool _active = false, _loading = false, _pending = false;
  int _revision = 0;
  int _boundedRefreshes = 0;
  bool _allowRead = true, _invalidated = false;
  String? _readThrough;
  void setAutoRefresh(bool active) {
    _allowRead = active;
    if (_active == active) return;
    _active = active && !_invalidated;
    _typing?.setActive(_active);
    _timer?.cancel();
    if (_active) {
      unawaited(load(silent: true));
      _timer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(load(silent: true)),
      );
    }
  }

  void invalidate() {
    _boundedRefreshes = 0;
    _invalidated = true;
    _revision++;
    _readThrough = null;
    _pending = false;
    setAutoRefresh(false);
    if (!isClosed) emit(const ConversationState());
  }

  void _mutating() {
    stopTyping();
    _revision++;
  }

  Future<bool> interact(String id, {String? emoji}) async {
    final repository = _repository;
    if (_invalidated ||
        isClosed ||
        state.isSending ||
        repository is! ChatInteractionRepository) {
      return false;
    }
    _mutating();
    final revision = _revision;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final updated = emoji == null
          ? await (repository as ChatInteractionRepository).togglePin(id)
          : await (repository as ChatInteractionRepository).react(id, emoji);
      if (isClosed || revision != _revision) return false;
      emit(
        state.copyWith(
          isSending: false,
          messages: state.messages
              .map(
                (m) => m.id == id
                    ? m.copyWith(
                        pinned: updated.pinned,
                        reactions: updated.reactions,
                      )
                    : m,
              )
              .toList(),
        ),
      );
      _changed();
      return true;
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          state.copyWith(
            isSending: false,
            error: error is ChatException
                ? error.message
                : 'Не удалось сохранить действие.',
          ),
        );
      }
      return false;
    }
  }

  Future<List<ChatConversationModel>> forwardTargets() =>
      _repository.getConversations();
  Future<bool> forward(
    ChatMessageModel message,
    ChatConversationModel target,
  ) async {
    final repository = _repository;
    if (_invalidated ||
        isClosed ||
        state.isSending ||
        repository is! ChatInteractionRepository) {
      return false;
    }
    _mutating();
    final revision = _revision;
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final forwarded = await (repository as ChatInteractionRepository)
          .forwardMessage(message, target);
      if (isClosed || revision != _revision) return false;
      emit(
        state.copyWith(
          isSending: false,
          messages: target.threadId == conversation.threadId
              ? _unique([...state.messages, forwarded])
              : state.messages,
        ),
      );
      _changed();
      return true;
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          state.copyWith(
            isSending: false,
            error: error is ChatException
                ? error.message
                : 'Не удалось переслать сообщение.',
          ),
        );
      }
      return false;
    }
  }

  void _changed() {
    notifyChatListChanges();
    _pending = false;
  }

  List<ChatMessageModel> _unique(List<ChatMessageModel> messages) =>
      {for (final message in messages) message.id: message}.values.toList();

  Future<bool> messageAction(String id, String action, {String? text}) async {
    final repository = _repository;
    if (_invalidated ||
        repository is! ChatActionsRepository ||
        state.isSending) {
      return false;
    }
    _mutating();
    final revision = _revision;
    emit(state.copyWith(isSending: true, isLoading: false, clearError: true));
    try {
      final actions = repository as ChatActionsRepository;
      if (action == 'favorite') {
        await actions.toggleFavorite(id);
      } else if (action == 'edit' && text != null && text.trim().isNotEmpty) {
        await actions.editMessage(id, text);
      } else if (action == 'delete') {
        await actions.deleteMessage(id);
      } else {
        throw const ChatException('Недоступное действие.');
      }
      if (isClosed || revision != _revision) return false;
      final messages = state.messages
          .where((e) => action != 'delete' || e.id != id)
          .map(
            (e) => e.id == id
                ? e.copyWith(
                    text: action == 'edit' ? text!.trim() : null,
                    favorited: action == 'favorite' ? !e.favorited : null,
                  )
                : e,
          )
          .toList();
      emit(state.copyWith(messages: messages, isSending: false));
      _changed();
      return true;
    } catch (e) {
      if (!isClosed && revision == _revision) {
        emit(
          state.copyWith(
            isSending: false,
            error: e is ChatException
                ? e.message
                : 'Не удалось сохранить сообщение.',
          ),
        );
      }
      return false;
    }
  }

  Future<void> load({bool silent = false}) async {
    if (isClosed || _invalidated) return;
    if (_loading || state.isSending) {
      _pending = true;
      return;
    }
    _loading = true;
    final revision = _revision;
    if (!silent) emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final repository = _repository;
      final useWindow =
          silent &&
          repository is ChatRefreshRepository &&
          state.messages.isNotEmpty &&
          _boundedRefreshes < 5;
      final messages = _unique(
        useWindow
            ? await (repository as ChatRefreshRepository).refreshMessages(
                conversation.threadId,
                state.messages,
              )
            : await repository.getMessages(conversation.threadId),
      );
      if (isClosed || revision != _revision) return;
      _boundedRefreshes = useWindow ? _boundedRefreshes + 1 : 0;
      emit(
        state.copyWith(messages: messages, isLoading: false, clearError: true),
      );
      final last = messages.lastOrNull?.id;
      if (_allowRead &&
          last != null &&
          last != _readThrough &&
          repository is ChatActionsRepository) {
        try {
          await (repository as ChatActionsRepository).markRead(
            conversation.threadId,
          );
          if (!isClosed && revision == _revision && _allowRead) {
            _readThrough = last;
            notifyChatListChanges();
          }
        } catch (_) {
          /* Retry read receipt after network recovery. */
        }
      }
    } catch (error) {
      if (!isClosed && revision == _revision && !silent) {
        emit(
          state.copyWith(
            isLoading: false,
            error: error is ChatException
                ? error.message
                : 'Не удалось обновить сообщения.',
          ),
        );
      }
    } finally {
      _loading = false;
      if (_pending && !isClosed && !state.isSending) {
        _pending = false;
        if (_active) unawaited(load(silent: true));
      }
    }
  }

  Future<bool> sendVoice(String dataUrl, int duration) async {
    if (_invalidated || state.isSending || !dataUrl.startsWith('data:audio/')) {
      return false;
    }
    _mutating();
    final revision = _revision;
    emit(state.copyWith(isSending: true, isLoading: false, clearError: true));
    try {
      final message = await _repository.sendMessage(
        conversation: conversation,
        text: '',
        kind: ChatMessageKind.audio,
        transcript: dataUrl,
        duration: duration,
      );
      if (isClosed || revision != _revision) return false;
      emit(
        state.copyWith(
          messages: _unique([...state.messages, message]),
          isSending: false,
        ),
      );
      _changed();
      return true;
    } catch (error) {
      if (!isClosed && revision == _revision) {
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
    if (_invalidated || state.isSending || !dataUrl.startsWith('data:')) {
      return false;
    }
    _mutating();
    final revision = _revision;
    emit(state.copyWith(isSending: true, isLoading: false, clearError: true));
    try {
      final message = await _repository.sendMessage(
        conversation: conversation,
        text: text,
        kind: ChatMessageKind.text,
        mention: dataUrl,
        duration: duration,
      );
      if (isClosed || revision != _revision) return false;
      emit(
        state.copyWith(
          messages: _unique([...state.messages, message]),
          isSending: false,
        ),
      );
      _changed();
      return true;
    } catch (error) {
      if (!isClosed && revision == _revision) {
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
    if (_invalidated || text.trim().isEmpty || state.isSending) return false;
    _mutating();
    stopTyping();
    final reply = state.replyTo;
    final excerpt = reply == null
        ? ''
        : String.fromCharCodes(reply.preview.runes.take(80));
    final payload = reply == null
        ? text.trim()
        : '↩ @${reply.authorName}: «$excerpt${reply.preview.runes.length > 80 ? '…' : ''}»\n\n${text.trim()}';
    final revision = _revision;
    emit(state.copyWith(isSending: true, isLoading: false, clearError: true));
    try {
      final message = await _repository.sendMessage(
        conversation: conversation,
        text: payload,
      );
      if (isClosed || revision != _revision) return false;
      emit(
        state.copyWith(
          messages: _unique([...state.messages, message]),
          isSending: false,
          clearReply: true,
        ),
      );
      _changed();
      return true;
    } catch (error) {
      if (!isClosed && revision == _revision) {
        emit(
          state.copyWith(
            isSending: false,
            error: error is ChatException
                ? error.message
                : 'Не удалось отправить сообщение.',
          ),
        );
      }
      return false;
    }
  }
}
