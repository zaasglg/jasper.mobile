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
  }) : super(const AssistantState());
  final AssistantRepository _repository;
  final WorkspaceRepository _workspaces;
  final WorkspaceSelectionStorage _selection;
  final AssistantActions? actions;
  String? currentProjectId;
  String? currentProjectName;
  int _revision = 0;
  void resolve(int index, String status, {String actionKey = "create"}) {
    if (isClosed || index >= state.messages.length) return;
    final messages = [...state.messages];
    messages[index] = messages[index].copyWith(
      actionStates: {...messages[index].actionStates, actionKey: status},
    );
    emit(state.copyWith(messages: messages));
  }

  Future<void> initialize() async {
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
      emit(
        AssistantState(
          workspaceId: selected.id,
          workspaceName: selected.name,
          status: AssistantStatus.ready,
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

  Future<void> ask(String text, {List<String> images = const []}) async {
    final content = text.trim();
    if ((content.isEmpty && images.isEmpty) ||
        state.workspaceId.isEmpty ||
        state.status == AssistantStatus.sending) {
      return;
    }
    final revision = ++_revision;
    final messages = [
      ...state.messages,
      AssistantMessageModel(role: 'user', content: content, images: images),
    ];
    emit(
      state.copyWith(
        status: AssistantStatus.sending,
        messages: messages,
        clearError: true,
      ),
    );
    try {
      await actions?.checkWorkspace(state.workspaceId);
      final draft = await actions?.extractDraft(
        state.workspaceId,
        content,
        images,
        currentProjectId,
      );
      if (isClosed || revision != _revision) return;
      if (draft != null) {
        emit(
          state.copyWith(
            status: AssistantStatus.ready,
            messages: [
              ...messages,
              AssistantMessageModel(
                role: 'assistant',
                content: '',
                draft: draft,
              ),
            ],
            clearError: true,
          ),
        );
        return;
      }
      await actions?.checkWorkspace(state.workspaceId);
      final reply = await _repository.chat(
        workspaceId: state.workspaceId,
        messages: messages.where((e) => e.draft == null).toList(),
        images: images,
        currentProjectId: currentProjectId,
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
    emit(
      state.copyWith(
        status: AssistantStatus.ready,
        messages: state.messages.take(state.messages.length - 1).toList(),
        clearError: true,
      ),
    );
    await ask(text, images: images);
  }
}
