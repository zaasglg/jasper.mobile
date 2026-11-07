import '../../data/services/assistant_task_changes.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/assistant_message_model.dart';
import '../../data/services/assistant_actions.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../cubit/assistant_cubit.dart';
import '../../../storage/data/storage_models.dart';
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
  });
  final AssistantMessageModel message;
  final int index;
  @override
  Widget build(BuildContext context) {
    final workspaceId = context.read<AssistantCubit>().state.workspaceId;
    final activity = <String>{};
    final files = <String, Map>{};
    final edits = <String, Map<String, dynamic>>{};
    for (final tool in message.tools) {
      final result = tool['result'];
      if (result is! Map || result.containsKey('error')) continue;
      final label = _toolLabels[tool['name']];
      if (label != null) activity.add(label);
      if (tool['name'] == 'search_messages' && result['results'] is List) {
        for (final row in result['results'] as List) {
          final file = row is Map ? row['attachment'] : null;
          if (file is Map &&
              file['messageId'] is String &&
              file['name'] is String) {
            files[file['messageId'] as String] = file;
          }
        }
      }
      final draft = result['draft'];
      if (tool['name'] == 'prepare_task_edit' &&
          draft is Map &&
          AssistantActions.validEdit(draft, workspaceId)) {
        edits['${draft['taskId']}:${draft['patch']}'] =
            Map<String, dynamic>.from(draft);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activity.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Использованные инструменты · ${activity.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              children: [
                for (final label in activity)
                  ListTile(
                    dense: true,
                    title: Text(label, style: const TextStyle(fontSize: 12)),
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
                side: const BorderSide(color: Color(0xffe6e6e3)),
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
                        title: 'Найденные файлы',
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
                      const SnackBar(content: Text('Не удалось открыть файл.')),
                    );
                  }
                }
              },
            ),
          ),
        if (message.draft != null)
          _DraftCard(
            key: ValueKey('create-$index'),
            draft: message.draft!,
            index: index,
          ),
        for (final draft in edits.values)
          _DraftCard(
            key: ValueKey('edit-$index-${draft['taskId']}-${draft['patch']}'),
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
  });
  final Map<String, dynamic> draft;
  final int index;
  final bool edit;
  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  List<Map<String, dynamic>> _projects = [];
  String? _projectId, _error, _resolved;
  bool _busy = false, _loading = false;
  String get actionKey => widget.edit
      ? 'edit:${widget.draft['taskId']}:${widget.draft['patch']}'
      : 'create';
  AssistantCubit get cubit => context.read<AssistantCubit>();
  @override
  void initState() {
    super.initState();
    _resolved = cubit.state.messages[widget.index].actionStates[actionKey];
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
    if (_busy || _resolved != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.edit) {
        await cubit.actions!.apply(cubit.state.workspaceId, widget.draft);
      } else {
        await cubit.actions!.create(
          cubit.state.workspaceId,
          _projectId!,
          widget.draft,
        );
      }
      notifyAssistantTaskChanges();
      if (!mounted) return;
      setState(() => _resolved = widget.edit ? 'applied' : 'created');
      cubit.resolve(
        widget.index,
        widget.edit ? 'applied' : 'created',
        actionKey: actionKey,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AssistantException
              ? error.message
              : 'Не удалось сохранить. Попробуйте ещё раз.',
        );
      }
    } finally {
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
    final patch = draft['patch'] is Map ? draft['patch'] as Map : const {};
    final previous = draft['previous'] is Map
        ? draft['previous'] as Map
        : const {};
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
            '${draft['title']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            widget.edit
                ? 'Проверьте изменения перед сохранением.'
                : 'Задача ещё не создана. Проверьте черновик и подтвердите.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (widget.edit) ...[
            for (final key in patch.keys)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${labels[key]}: ${_value(key, previous[key])} → ${_value(key, patch[key])}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          if (!widget.edit) ...[
            if ('${draft['description'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${draft['description']}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (draft['dueDate'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Срок: ${draft['dueDate']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (draft['suggestedAssigneeName'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Участник: ${draft['suggestedAssigneeName']}${draft['resolvedAssigneeId'] == null ? ' (не найден)' : ''}',
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
                        hint: const Text('Выберите проект'),
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
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          if (_error != null && !widget.edit && _projects.isEmpty)
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Загрузить проекты'),
            ),
          const SizedBox(height: 12),
          if (_resolved != null)
            Text(
              _resolved == 'created'
                  ? 'Задача создана'
                  : _resolved == 'applied'
                  ? 'Изменения сохранены'
                  : 'Изменения отменены',
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed:
                      _busy || _loading || (!widget.edit && _projectId == null)
                      ? null
                      : _submit,
                  child: Text(
                    _busy
                        ? 'Сохраняю…'
                        : widget.edit
                        ? 'Применить'
                        : 'Добавить задачу',
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
                  child: const Text('Отменить'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
