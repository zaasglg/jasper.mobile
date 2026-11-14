import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/theme/task_label_color.dart';
import '../../../../core/widgets/app_color_picker.dart';
import '../../../tasks/domain/repositories/task_details_repository.dart';
import '../../../kanban/presentation/cubit/kanban_cubit.dart';
import '../../data/models/project_task_model.dart';
import '../../domain/repositories/project_task_repository.dart';

typedef _EpicData = (List<TaskEpicModel>, List<ProjectTaskModel>);

enum _EpicFilter { all, withTasks, empty, completed }

class ProjectEpicsScreen extends StatefulWidget {
  const ProjectEpicsScreen({
    required this.projectId,
    this.boardCubit,
    super.key,
  });

  final String projectId;
  final KanbanCubit? boardCubit;

  @override
  State<ProjectEpicsScreen> createState() => _ProjectEpicsScreenState();
}

class _ProjectEpicsScreenState extends State<ProjectEpicsScreen> {
  late Future<_EpicData> _future;
  final _search = TextEditingController();
  _EpicFilter _filter = _EpicFilter.all;
  bool _creating = false;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...?widget.boardCubit?.state.epicFilterIds};
    _future = _load();
  }

  void _select(String id, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    _syncFilter();
  }

  void _syncFilter() {
    final cubit = widget.boardCubit;
    if (cubit != null &&
        !cubit.isClosed &&
        cubit.state.projectId == widget.projectId) {
      cubit.setEpicFilter(_selected);
    }
  }

  Future<_EpicData> _load() async {
    final repository = sl<TaskDetailsRepository>();
    if (repository is! TaskExtrasRepository) {
      throw const TaskDetailsException('Список эпиков недоступен.');
    }
    final results = await Future.wait<Object>([
      (repository as TaskExtrasRepository).getEpics(widget.projectId),
      sl<ProjectTaskRepository>().getTasksForProjectIds([widget.projectId]),
    ]);
    return (
      results[0] as List<TaskEpicModel>,
      results[1] as List<ProjectTaskModel>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error and retry action.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Эпики проекта'),
      actions: [
        IconButton(
          key: const Key('epics-add'),
          tooltip: 'Создать эпик',
          onPressed: () => setState(() => _creating = true),
          icon: const Icon(LucideIcons.plus),
        ),
        IconButton(
          key: const Key('epics-refresh'),
          tooltip: 'Обновить',
          onPressed: _refresh,
          icon: const Icon(LucideIcons.refreshCw),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_creating)
            Flexible(
              child: SingleChildScrollView(
                child: _EpicCreationForm(
                  projectId: widget.projectId,
                  onCancel: () => setState(() => _creating = false),
                  onCreated: () {
                    setState(() {
                      _creating = false;
                      _search.clear();
                      _filter = _EpicFilter.all;
                    });
                    _refresh();
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              key: const Key('epics-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск эпиков',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить поиск',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(LucideIcons.x),
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                for (final filter in _EpicFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      key: ValueKey('epics-filter-${filter.name}'),
                      label: Text(switch (filter) {
                        _EpicFilter.all => 'Все',
                        _EpicFilter.withTasks => 'С задачами',
                        _EpicFilter.empty => 'Без задач',
                        _EpicFilter.completed => 'Завершённые',
                      }),
                      selected: filter == _filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_EpicData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Не удалось загрузить эпики'),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                final (catalog, tasks) = snapshot.data!;
                final byEpic = <String, List<ProjectTaskModel>>{};
                final epics = {for (final epic in catalog) epic.id: epic};
                for (final task in tasks) {
                  for (final epic in task.epics) {
                    epics.putIfAbsent(epic.id, () => epic);
                    (byEpic[epic.id] ??= []).add(task);
                  }
                }
                final query = _search.text.trim().toLowerCase();
                final visible =
                    epics.values.where((epic) {
                      if (!epic.name.toLowerCase().contains(query)) {
                        return false;
                      }
                      final linked = byEpic[epic.id] ?? [];
                      return switch (_filter) {
                        _EpicFilter.all => true,
                        _EpicFilter.withTasks => linked.isNotEmpty,
                        _EpicFilter.empty => linked.isEmpty,
                        _EpicFilter.completed =>
                          linked.isNotEmpty &&
                              linked.every((task) => task.isDone),
                      };
                    }).toList()..sort(
                      (a, b) =>
                          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                    );
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      epics.isEmpty
                          ? 'В проекте пока нет эпиков'
                          : 'По выбранным фильтрам эпиков нет',
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final epic = visible[index];
                      return _EpicTile(
                        key: ValueKey(epic.id),
                        epic: epic,
                        tasks: byEpic[epic.id] ?? const [],
                        selected: _selected.contains(epic.id),
                        onSelected: (value) => _select(epic.id, value),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (widget.boardCubit != null || _selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('epics-show-board'),
                      onPressed: () => context.pop(),
                      child: Text(
                        _selected.isEmpty
                            ? 'Показать все задачи'
                            : 'Показать на доске (${_selected.length})',
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('epics-clear-selection'),
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            setState(_selected.clear);
                            _syncFilter();
                          },
                    child: const Text('Сбросить'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _EpicCreationForm extends StatefulWidget {
  const _EpicCreationForm({
    required this.projectId,
    required this.onCreated,
    required this.onCancel,
  });

  final String projectId;
  final VoidCallback onCreated;
  final VoidCallback onCancel;

  @override
  State<_EpicCreationForm> createState() => _EpicCreationFormState();
}

class _EpicCreationFormState extends State<_EpicCreationForm> {
  final _name = TextEditingController();
  String _color = '#E11D48';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = sl<TaskDetailsRepository>();
      if (repository is! ProjectEpicCreationRepository) {
        throw const TaskDetailsException('Создание эпиков недоступно.');
      }
      await (repository as ProjectEpicCreationRepository).createEpic(
        projectId: widget.projectId,
        name: _name.text.trim(),
        color: _color,
      );
      if (!mounted) return;
      widget.onCreated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is TaskDetailsException
            ? error.message
            : 'Не удалось создать эпик. Попробуйте ещё раз.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('epic-name'),
          controller: _name,
          autofocus: true,
          enabled: !_saving,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(hintText: 'Название эпика...'),
        ),
        const SizedBox(height: AppSpacing.smMd),
        AppColorPicker(
          value: _color,
          enabled: !_saving,
          extraColors: const [Color(0xFF94A3B8)],
          onChanged: (color) => setState(() => _color = color),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.smMd),
        Row(
          children: [
            FilledButton(
              key: const Key('epic-create-submit'),
              onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
              child: Text(_saving ? 'Создание...' : 'Создать эпик'),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              key: const Key('epic-create-cancel'),
              tooltip: 'Отмена',
              onPressed: _saving ? null : widget.onCancel,
              icon: const Icon(LucideIcons.x),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EpicTile extends StatelessWidget {
  const _EpicTile({
    required this.epic,
    required this.tasks,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final TaskEpicModel epic;
  final List<ProjectTaskModel> tasks;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isDone).length;
    return ListTileTheme(
      horizontalTitleGap: AppSpacing.sm,
      minLeadingWidth: AppSpacing.touchTarget,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.touchTarget + AppSpacing.sm,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Checkbox(
          key: ValueKey('epic-filter-${epic.id}'),
          semanticLabel: 'Фильтровать по эпику ${epic.name}',
          value: selected,
          onChanged: (value) => onSelected(value ?? false),
        ),
        title: Text(
          epic.name,
          style: AppTypography.title(
            context,
          )?.copyWith(color: taskLabelColor(epic.color)),
        ),
        subtitle: Text(
          tasks.isEmpty
              ? 'Нет связанных задач'
              : 'Завершено $completed из ${tasks.length} задач',
        ),
        children: [
          for (final task in tasks)
            ListTile(
              leading: Icon(
                task.isDone ? LucideIcons.circleCheck : LucideIcons.circle,
              ),
              title: Text(task.title),
              subtitle: task.displayId.isEmpty ? null : Text(task.displayId),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.push('/tasks/${task.id}', extra: task),
            ),
        ],
      ),
    );
  }
}
