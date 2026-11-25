import 'dart:async';
import '../../domain/entities/assistant_conversation.dart';
import '../../domain/entities/assistant_request.dart';
import '../../domain/repositories/assistant_history_repository.dart';
import '../../domain/entities/assistant_attachment.dart';
import '../../data/services/assistant_actions.dart';
import '../../data/services/assistant_task_changes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../../workspaces/domain/repositories/workspace_repository.dart';
import '../../domain/entities/assistant_message_model.dart';
import '../../domain/repositories/assistant_repository.dart';
import 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(
    this._repository,
    this._workspaces,
    this._selection, {
    this.actions,
    this.history,
  }) : super(const AssistantState());
  final AssistantRepository _repository;
  final WorkspaceRepository _workspaces;
  final WorkspaceSelectionStorage _selection;
  final AssistantActions? actions;
  final AssistantHistoryRepository? history;
  String? _historyScope;
  AssistantRequest? _request;
  Timer? _draftTimer;
  Future<void> _saves = Future.value();
  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  bool beginAction() {
    if (isClosed ||
        state.actionBusy ||
        state.status == AssistantStatus.sending) {
      return false;
    }
    emit(state.copyWith(actionBusy: true));
    return true;
  }

  void endAction() {
    if (!isClosed) emit(state.copyWith(actionBusy: false));
  }

  void updateDraft(String text) {
    if (isClosed || state.workspaceId.isEmpty || text == state.draft) return;
    emit(state.copyWith(draft: text));
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _persist);
  }

  Future<void> _persist() {
    _draftTimer?.cancel();
    if (isClosed || state.conversationId.isEmpty) return Future.value();
    final snapshot = AssistantConversation(
      id: state.conversationId,
      updatedAt: DateTime.now(),
      messages: [
        for (var i = 0; i < state.messages.length; i++)
          if (state.status == AssistantStatus.sending &&
              i == state.messages.length - 1)
            state.messages[i].copyWith(cancelled: true)
          else
            state.messages[i],
      ],
      draft: state.draft,
      projectId: currentProjectId,
      projectName: currentProjectName,
      stopped: state.stopped || state.status == AssistantStatus.sending,
    );
    final conversations = [
      snapshot,
      ...state.conversations.where(
        (c) =>
            c.id != snapshot.id &&
            (c.messages.isNotEmpty || c.draft.isNotEmpty),
      ),
    ];
    emit(state.copyWith(conversations: conversations));
    final scope = _historyScope;
    if (history == null || scope == null) return Future.value();
    final operation = _saves.then((_) => history!.save(scope, conversations));
    _saves = operation.then<void>(
      (_) {
        if (!isClosed) emit(state.copyWith(clearHistoryError: true));
      },
      onError: (Object _, StackTrace _) {
        if (!isClosed) {
          emit(
            state.copyWith(
              historyError:
                  'Не удалось сохранить историю. Освободите место или повторите позже.',
            ),
          );
        }
      },
    );
    return _saves;
  }

  void stop() {
    if (isClosed || state.status != AssistantStatus.sending) return;
    _revision++;
    _request?.cancel();
    emit(
      state.copyWith(
        status: AssistantStatus.ready,
        stopped: true,
        messages: [
          for (var i = 0; i < state.messages.length; i++)
            i == state.messages.length - 1
                ? state.messages[i].copyWith(cancelled: true)
                : state.messages[i],
        ],
        clearError: true,
      ),
    );
    unawaited(_persist());
  }

  Future<void> saveHistory() => _persist();

  Future<void> newConversation() async {
    if (state.actionBusy || state.status == AssistantStatus.sending) return;
    unawaited(_persist());
    if (isClosed) return;
    _revision++;
    emit(
      state.copyWith(
        conversationId: _newId(),
        messages: [],
        draft: '',
        restoredMessageCount: 0,
        stopped: false,
        clearError: true,
      ),
    );
    unawaited(_persist());
  }

  Future<void> openConversation(String id) async {
    if (state.actionBusy ||
        state.status == AssistantStatus.sending ||
        id == state.conversationId) {
      return;
    }
    unawaited(_persist());
    if (isClosed) return;
    final conversation = state.conversations
        .where((c) => c.id == id)
        .firstOrNull;
    if (conversation == null) return;
    _revision++;
    currentProjectId = conversation.projectId;
    currentProjectName = conversation.projectName;
    emit(
      state.copyWith(
        conversationId: id,
        messages: conversation.messages,
        draft: conversation.draft,
        stopped: conversation.stopped,
        restoredMessageCount: conversation.messages.length,
        clearError: true,
      ),
    );
    unawaited(_persist());
  }

  Future<void> deleteConversation(String id) async {
    if (state.actionBusy || state.status == AssistantStatus.sending) return;
    if (id == state.conversationId) {
      emit(
        state.copyWith(
          conversationId: _newId(),
          messages: [],
          draft: '',
          restoredMessageCount: 0,
          stopped: false,
          clearError: true,
        ),
      );
    }
    emit(
      state.copyWith(
        conversations: state.conversations.where((c) => c.id != id).toList(),
      ),
    );
    await _persist();
  }

  @override
  Future<void> close() async {
    _request?.cancel();
    _revision++;
    await _persist();
    _draftTimer?.cancel();
    await super.close();
  }

  String? currentProjectId;
  String? currentProjectName;
  int _revision = 0;
  void resolve(int index, String status, {String actionKey = "create"}) {
    if (isClosed || index < 0 || index >= state.messages.length) return;
    final messages = [...state.messages];
    messages[index] = messages[index].copyWith(
      actionStates: {...messages[index].actionStates, actionKey: status},
    );
    emit(state.copyWith(messages: messages));
    unawaited(_persist());
  }

  Future<void> initialize() async {
    _historyScope = null;
    _request?.cancel();
    final revision = ++_revision;
    emit(const AssistantState());
    try {
      final workspaces = await _workspaces.getWorkspaces();
      final savedId = await _selection.read();
      if (isClosed || revision != _revision) return;
      final selected =
          workspaces.where((e) => e.id == savedId).firstOrNull ??
          workspaces.firstOrNull;
      if (selected == null) {
        emit(
          const AssistantState(
            status: AssistantStatus.failure,
            error: 'Сначала создайте рабочее пространство.',
          ),
        );
        return;
      }
      if (currentProjectId != null && actions != null) {
        final projects = await actions!.projects(selected.id);
        final project = projects
            .where((e) => e['id'] == currentProjectId)
            .firstOrNull;
        currentProjectId = project?['id'] as String?;
        currentProjectName = project?['name'] as String?;
      }
      if (isClosed || revision != _revision) return;
      List<AssistantConversation> conversations = [];
      String? historyError;
      try {
        _historyScope = await history?.scope(selected.id);
        if (history != null && _historyScope == null) {
          historyError = 'История недоступна для текущей сессии.';
        }
        if (_historyScope != null) {
          conversations = await history!.load(_historyScope!);
        }
      } catch (_) {
        historyError = 'Не удалось загрузить историю диалогов.';
      }
      if (isClosed || revision != _revision) return;
      final latest = conversations
          .where(
            (c) => currentProjectId == null || c.projectId == currentProjectId,
          )
          .firstOrNull;
      if (latest != null) {
        currentProjectId = latest.projectId;
        currentProjectName = latest.projectName;
      }
      emit(
        AssistantState(
          workspaceId: selected.id,
          workspaceName: selected.name,
          status: AssistantStatus.ready,
          conversations: conversations,
          conversationId: latest?.id ?? _newId(),
          messages: latest?.messages ?? [],
          draft: latest?.draft ?? '',
          stopped: latest?.stopped ?? false,
          restoredMessageCount: latest?.messages.length ?? 0,
          historyError: historyError,
        ),
      );
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          const AssistantState(
            status: AssistantStatus.failure,
            error: 'Не удалось загрузить рабочее пространство.',
          ),
        );
      }
    }
  }

  Future<void> ask(
    String text, {
    List<String> images = const [],
    List<AssistantAttachment> attachments = const [],
  }) async {
    final content = text.trim();
    if (isClosed ||
        (content.isEmpty && images.isEmpty && attachments.isEmpty) ||
        state.workspaceId.isEmpty ||
        state.actionBusy ||
        state.status == AssistantStatus.sending) {
      return;
    }
    final revision = ++_revision;
    final request = AssistantRequest();
    _request = request;
    final messages = [
      ...state.messages,
      AssistantMessageModel(
        role: 'user',
        content: content,
        images: images,
        attachments: attachments,
      ),
    ];
    emit(
      state.copyWith(
        status: AssistantStatus.sending,
        messages: messages,
        clearError: true,
        stopped: false,
        draft: '',
      ),
    );
    unawaited(_persist());
    try {
      await actions?.checkWorkspace(state.workspaceId);
      if (isClosed || revision != _revision) return;
      final extracted = attachments.isNotEmpty
          ? await actions?.extractAttachmentMessage(
              state.workspaceId,
              content,
              attachments,
              images,
              currentProjectId,
              request: request,
            )
          : null;
      final draft = attachments.isEmpty
          ? await actions?.extractDraft(
              state.workspaceId,
              content,
              images,
              currentProjectId,
              request: request,
            )
          : null;
      if (isClosed || revision != _revision) return;
      if (extracted != null || draft != null) {
        emit(
          state.copyWith(
            status: AssistantStatus.ready,
            messages: [
              ...messages,
              extracted ??
                  AssistantMessageModel(
                    role: 'assistant',
                    content: '',
                    draft: draft,
                  ),
            ],
            responseRevision: state.responseRevision + 1,
            clearError: true,
          ),
        );
        return;
      }
      await actions?.checkWorkspace(state.workspaceId);
      if (isClosed || revision != _revision) return;
      final reply = await _repository.chat(
        workspaceId: state.workspaceId,
        messages: messages
            .where((e) => e.draft == null && !e.cancelled)
            .toList(),
        images: images,
        attachments: attachments,
        currentProjectId: currentProjectId,
        request: request,
      );
      if (isClosed || revision != _revision) return;
      await actions?.checkWorkspace(state.workspaceId);
      if (isClosed || revision != _revision) return;
      if (reply.tools.any((tool) {
        final result = tool.result;
        final updated = result?.updated;
        return tool.name == 'update_task' &&
            result != null &&
            !result.hasError &&
            updated != null &&
            updated['workspaceId'] == state.workspaceId;
      })) {
        notifyAssistantTaskChanges();
      }
      emit(
        state.copyWith(
          status: AssistantStatus.ready,
          messages: [...messages, reply],
          responseRevision: state.responseRevision + 1,
        ),
      );
    } catch (error) {
      if (isClosed || revision != _revision) return;
      emit(
        state.copyWith(
          status: AssistantStatus.failure,
          error: error is AssistantException
              ? error.message
              : 'Не удалось получить ответ.',
        ),
      );
    } finally {
      if (!isClosed && revision == _revision) await _persist();
    }
  }

  Future<void> retry() async {
    if (state.workspaceId.isEmpty) {
      await initialize();
      return;
    }
    if (state.status == AssistantStatus.sending ||
        state.messages.isEmpty ||
        state.messages.last.role != 'user') {
      return;
    }
    final text = state.messages.last.content;
    final images = state.messages.last.images;
    final attachments = state.messages.last.attachments;
    emit(
      state.copyWith(
        status: AssistantStatus.ready,
        messages: state.messages.take(state.messages.length - 1).toList(),
        clearError: true,
      ),
    );
    await ask(text, images: images, attachments: attachments);
  }
}
