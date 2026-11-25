import 'package:jospar/core/localization/app_translations.dart';
import '../cubit/assistant_state.dart';
import '../../domain/entities/assistant_tool.dart';
import '../../domain/entities/assistant_draft.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/services/assistant_task_changes.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/assistant_message_model.dart';
import '../../data/services/assistant_actions.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../cubit/assistant_cubit.dart';
import '../../../storage/domain/entities/storage_scope.dart';
import '../../../storage/domain/entities/storage_item.dart';
import '../../../storage/domain/entities/storage_enums.dart';
import '../../../storage/presentation/storage_file_screen.dart';

const _toolLabels = {
  'search_workspace': 'Поиск в рабочем пространстве',
  'open_task': 'Открытие карточки задачи',
  'get_task_details': 'Данные задачи',
  'create_task_draft': 'Подготовка черновика',
  'prepare_task_edit': 'Подготовка изменений задачи',
  'update_task': 'Сохранение изменений задачи',
  'analyze_project_risks': 'Анализ рисков проекта',
  'get_my_priority_tasks': 'Мои задачи',
  'get_project_status': 'Статус проекта',
  'search_messages': 'Поиск сообщений',
  'get_discussion_context': 'Контекст обсуждения',
};

class AssistantActionCards extends StatelessWidget {
  const AssistantActionCards({
    super.key,
    required this.message,
    required this.index,
    this.readOnly = false,
  });
  final AssistantMessageModel message;
  final int index;
  final bool readOnly;
  @override
  Widget build(BuildContext context) {
    final workspaceId = context.read<AssistantCubit>().state.workspaceId;
    bool succeeded(AssistantTool tool) =>
        tool.result != null &&
        !tool.result!.hasError &&
        (tool.name != 'update_task' ||
            tool.result!.updated?['workspaceId'] == workspaceId);

    final files = <String, Map>{};
    final edits = <String, AssistantDraft>{};
    for (final tool in message.tools) {
      final result = tool.result;
      if (result == null || result.hasError) continue;

      if (tool.name == 'search_messages' && result.results != null) {
        for (final row in result.results!) {
          final file = row is Map ? row['attachment'] : null;
          if (file is Map &&
              file['messageId'] is String &&
              file['name'] is String) {
            files[file['messageId'] as String] = file;
          }
        }
      }
      final draft = result.draft;
      if (tool.name == 'prepare_task_edit' &&
          draft != null &&
          AssistantActions.validDraftEdit(draft, workspaceId)) {
        edits['${draft.taskId}:${draft.patch}'] = draft;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message.tools.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                tr(context, "Действия · {p0} выполнено", {
                      'p0': message.tools.where(succeeded).length,
                    }) +
                    (message.tools.any((t) => t.result?.hasError == true)
                        ? tr(context, ' · есть ошибки')
                        : ''),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.of(context).ink,
                ),
              ),
              children: [
                for (final tool in message.tools)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      !succeeded(tool) && tool.result?.hasError != true
                          ? Icons.help_outline
                          : tool.result!.hasError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: tool.result?.hasError == true
                          ? AppColors.of(context).error
                          : AppColors.of(context).muted,
                    ),
                    title: Text(
                      tr(
                        context,
                        _toolLabels[tool.name] ?? 'Действие помощника',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      tool.result == null
                          ? tr(context, 'Нет подтверждения выполнения')
                          : tool.result!.hasError
                          ? tr(context, 'Не удалось выполнить')
                          : !succeeded(tool)
                          ? tr(context, 'Сервер не подтвердил сохранение')
                          : tool.name == 'update_task'
                          ? tr(context, "Изменения сохранены{p0}", {
                              'p0': tool.result!.updated?['title'] is String
                                  ? ': ${tool.result!.updated!['title']}'
                                  : '',
                            })
                          : tr(context, 'Выполнено'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        for (final file in files.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.of(context).border),
              ),
              leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
              title: Text(
                file['name'] as String,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: file['size'] == null
                  ? null
                  : Text(
                      '${file['size']}',
                      style: const TextStyle(fontSize: 12),
                    ),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                try {
                  final url = file['url'];
                  if (url is String && url.isNotEmpty) {
                    await openStorageLink(url);
                    return;
                  }
                  if (!context.mounted) return;
                  await context.push(
                    '/storage-file',
                    extra: (
                      StorageScope(
                        source: StorageSource.chat,
                        id: '',
                        workspaceId: workspaceId,
                        title: tr(context, 'Найденные файлы'),
                      ),
                      StorageItem(
                        id: file['messageId'] as String,
                        messageId: file['messageId'] as String,
                        name: file['name'] as String,
                        kind:
                            (lookupMimeType(file['name'] as String) ?? '')
                                .startsWith('image/')
                            ? StorageFileKind.image
                            : (file['name'] as String).toLowerCase().endsWith(
                                '.pdf',
                              )
                            ? StorageFileKind.pdf
                            : StorageFileKind.other,
                        mimeType: lookupMimeType(file['name'] as String) ?? '',
                        date: DateTime.now(),
                        sizeLabel: '${file['size'] ?? ''}',
                      ),
                    ),
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      appSnackBar(
                        context: context,
                        tone: AppSnackBarTone.error,
                        content: Text(tr(context, 'Не удалось открыть файл.')),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        if (message.draft != null)
          _DraftCard(
            key: ValueKey('create-$index'),
            readOnly: readOnly,
            draft: message.draft!,
            index: index,
          ),
        for (final draft in edits.values)
          _DraftCard(
            key: ValueKey('edit-$index-${draft.taskId}-${draft.patch}'),
            readOnly: readOnly,
            draft: draft,
            index: index,
            edit: true,
          ),
      ],
    );
  }
}

class _DraftCard extends StatefulWidget {
  const _DraftCard({
    super.key,
    required this.draft,
    required this.index,
    this.edit = false,
    this.readOnly = false,
  });
  final AssistantDraft draft;
  final int index;
  final bool edit, readOnly;
  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  List<Map<String, dynamic>> _projects = [];
  String? _projectId, _error, _resolved;
  bool _busy = false, _loading = false;
  String get actionKey => widget.edit
      ? 'edit:${widget.draft.taskId}:${widget.draft.patch}'
      : 'create';
  AssistantCubit get cubit => context.read<AssistantCubit>();
  @override
  void initState() {
    super.initState();
    _resolved = cubit.state.messages[widget.index].actionStates[actionKey];
    if (widget.readOnly && _resolved == null) _resolved = 'history';
    if (!widget.edit && _resolved == null) {
      _projectId = cubit.currentProjectId;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await cubit.actions!.projects(cubit.state.workspaceId);
      if (mounted) {
        setState(() {
          _projects = projects;
          if (!_projects.any((e) => e['id'] == _projectId)) _projectId = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить проекты.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final operationCubit = cubit;
    if (_busy ||
        _resolved != null ||
        widget.readOnly ||
        !operationCubit.beginAction()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.edit) {
        await operationCubit.actions!.applyDraft(
          operationCubit.state.workspaceId,
          widget.draft,
        );
      } else {
        await operationCubit.actions!.createDraft(
          operationCubit.state.workspaceId,
          _projectId!,
          widget.draft,
        );
      }
      notifyAssistantTaskChanges();
      operationCubit.resolve(
        widget.index,
        widget.edit ? 'applied' : 'created',
        actionKey: actionKey,
      );
      if (!mounted) return;
      setState(() => _resolved = widget.edit ? 'applied' : 'created');
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AssistantException
              ? error.message
              : 'Не удалось сохранить. Попробуйте ещё раз.',
        );
      }
    } finally {
      operationCubit.endAction();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _value(String key, dynamic value) {
    if (value == null) return 'Без даты';
    if (key == 'priority') {
      return {
            'LOW': 'Низкий',
            'MED': 'Средний',
            'HIGH': 'Высокий',
            'CRIT': 'Критический',
          }[value] ??
          '$value';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final patch = draft.patch;
    final previous = draft.previous;
    final labels = {
      'title': 'Название',
      'start': 'Начало',
      'end': 'Срок',
      'priority': 'Приоритет',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffafaf9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe6e6e3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${draft.title}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            widget.edit
                ? tr(context, 'Проверьте изменения перед сохранением.')
                : tr(
                    context,
                    'Задача ещё не создана. Проверьте черновик и подтвердите.',
                  ),
            style: TextStyle(fontSize: 12, color: AppColors.of(context).muted),
          ),
          if (widget.edit) ...[
            for (final key in patch.keys)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${labels[key]}: ${_value(key, previous?.value(key))} → ${_value(key, patch[key])}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          if (!widget.edit) ...[
            if ((draft.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  draft.description!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (draft.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(context, "Срок: {p0}", {'p0': draft.dueDate}),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (draft.suggestedAssigneeName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(context, "Участник: {p0}{p1}", {
                    'p0': draft.suggestedAssigneeName,
                    'p1': draft.resolvedAssigneeId == null
                        ? ' (не найден)'
                        : '',
                  }),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (_resolved == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _loading
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                        initialValue: _projectId,
                        isExpanded: true,
                        hint: Text(tr(context, 'Выберите проект')),
                        items: [
                          for (final project in _projects)
                            DropdownMenuItem(
                              value: project['id'] as String,
                              child: Text(
                                '${project['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (id) => setState(() => _projectId = id),
                      ),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(context, _error!),
                style: TextStyle(
                  color: AppColors.of(context).error,
                  fontSize: 12,
                ),
              ),
            ),
          if (_error != null && !widget.edit && _projects.isEmpty)
            TextButton(
              onPressed: _loading ? null : _load,
              child: Text(tr(context, 'Загрузить проекты')),
            ),
          const SizedBox(height: 12),
          if (_resolved != null)
            Text(
              _resolved == 'created'
                  ? tr(context, 'Задача создана')
                  : _resolved == 'applied'
                  ? tr(context, 'Изменения сохранены')
                  : _resolved == 'history'
                  ? tr(
                      context,
                      'Черновик из истории. Отправьте новый запрос, чтобы проверить его актуальность.',
                    )
                  : widget.edit
                  ? tr(context, 'Изменения отменены')
                  : tr(context, 'Создание отменено'),
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed:
                      _busy ||
                          cubit.state.actionBusy ||
                          cubit.state.status == AssistantStatus.sending ||
                          _loading ||
                          (!widget.edit && _projectId == null)
                      ? null
                      : _submit,
                  child: Text(
                    _busy
                        ? tr(context, 'Сохраняю…')
                        : widget.edit
                        ? tr(context, 'Применить')
                        : tr(context, 'Добавить задачу'),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _resolved = 'cancelled');
                          cubit.resolve(
                            widget.index,
                            'cancelled',
                            actionKey: actionKey,
                          );
                        },
                  child: Text(tr(context, 'Отменить')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
