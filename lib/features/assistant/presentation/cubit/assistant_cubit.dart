import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../../workspaces/domain/repositories/workspace_repository.dart';
import '../../data/models/assistant_message_model.dart';
import '../../domain/repositories/assistant_repository.dart';
import 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit(this._repository, this._workspaces, this._selection)
    : super(const AssistantState());
  final AssistantRepository _repository;
  final WorkspaceRepository _workspaces;
  final WorkspaceSelectionStorage _selection;
  int _revision = 0;
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

  Future<void> ask(String text) async {
    final content = text.trim();
    if (content.isEmpty ||
        state.workspaceId.isEmpty ||
        state.status == AssistantStatus.sending) {
      return;
    }
    final revision = ++_revision;
    final messages = [
      ...state.messages,
      AssistantMessageModel(role: 'user', content: content),
    ];
    emit(
      state.copyWith(
        status: AssistantStatus.sending,
        messages: messages,
        clearError: true,
      ),
    );
    try {
      final reply = await _repository.chat(
        workspaceId: state.workspaceId,
        messages: messages,
      );
      if (isClosed || revision != _revision) return;
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
    emit(
      state.copyWith(
        status: AssistantStatus.ready,
        messages: state.messages.take(state.messages.length - 1).toList(),
        clearError: true,
      ),
    );
    await ask(text);
  }
}
