import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../projects/domain/repositories/project_task_repository.dart';
import '../cubit/task_details_cubit.dart';

bool createsTaskDependencyCycle(
  ProjectTaskModel task,
  ProjectTaskModel candidate,
  List<ProjectTaskModel> tasks,
) {
  final visited = <String>{};
  final byId = {for (final item in tasks) item.displayId: item};
  bool visit(String id) {
    if (id == task.displayId) return true;
    if (!visited.add(id)) return false;
    return byId[id]?.deps.any(visit) ?? false;
  }

  return visit(candidate.displayId);
}

class TaskRelationships extends StatefulWidget {
  const TaskRelationships({
    required this.task,
    required this.cubit,
    required this.enabled,
    super.key,
  });
  final ProjectTaskModel task;
  final TaskDetailsCubit cubit;
  final bool enabled;
  @override
  State<TaskRelationships> createState() => _TaskRelationshipsState();
}

class _TaskRelationshipsState extends State<TaskRelationships> {
  List<ProjectTaskModel> _tasks = [];
  bool _loading = false;
  String? _error;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TaskRelationships old) {
    super.didUpdateWidget(old);
    if (old.task.projectId != widget.task.projectId) _load();
  }

  Future<void> _load() async {
    if (!sl.isRegistered<ProjectTaskRepository>()) return;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await sl<ProjectTaskRepository>().getTasksForProjectIds([
        widget.task.projectId,
      ]);
      if (mounted && revision == _revision) {
        setState(() {
          _tasks = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
          _error = 'Не удалось загрузить зависимости.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DependencyEditor(task: widget.task, tasks: _tasks),
    );
    if (selected != null && mounted) {
      await widget.cubit.updateDependencies(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = _tasks.where(
      (t) => t.id != widget.task.id && t.deps.contains(widget.task.displayId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.link, size: AppIconSizes.standard),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Зависимости',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Изменить зависимости',
              onPressed: widget.enabled && !_loading && _error == null
                  ? _edit
                  : null,
              icon: const Icon(LucideIcons.pencil, size: AppIconSizes.standard),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Повторить')),
        if (widget.task.deps.isEmpty && outgoing.isEmpty)
          const Text(
            'Нет зависимостей',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        for (final id in widget.task.deps) _link(id, 'Зависит от'),
        for (final related in outgoing)
          _link(related.displayId, 'Зависит от этой задачи'),
      ],
    );
  }

  Widget _link(String id, String caption) {
    final related = _tasks.where((t) => t.displayId == id).firstOrNull;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        related == null ? id : '$id · ${related.title}',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(caption, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: AppIconSizes.standard,
      ),
      onTap: related == null
          ? null
          : () => context.push(
              '/tasks/${Uri.encodeComponent(related.id)}',
              extra: related,
            ),
    );
  }
}

class _DependencyEditor extends StatefulWidget {
  const _DependencyEditor({required this.task, required this.tasks});
  final ProjectTaskModel task;
  final List<ProjectTaskModel> tasks;
  @override
  State<_DependencyEditor> createState() => _DependencyEditorState();
}

class _DependencyEditorState extends State<_DependencyEditor> {
  late final Set<String> _selected = widget.task.deps.toSet();
  String _query = '';
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    MediaQuery.paddingOf(context).vertical -
                    24)
                .clamp(180.0, MediaQuery.sizeOf(context).height * .65),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Задача зависит от',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Поиск задач',
                prefixIcon: Icon(Icons.search, size: 16),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final task in widget.tasks.where(
                    (t) =>
                        t.id != widget.task.id &&
                        t.displayId.isNotEmpty &&
                        (!t.archived || _selected.contains(t.displayId)) &&
                        '${t.displayId} ${t.title}'.toLowerCase().contains(
                          _query,
                        ),
                  ))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(task.displayId),
                      title: Text(
                        task.title,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(task.displayId),
                      onChanged: (value) {
                        if (value == true &&
                            createsTaskDependencyCycle(
                              widget.task,
                              task,
                              widget.tasks,
                            )) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Эта связь создаст циклическую зависимость.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          if (value == true) {
                            _selected.add(task.displayId);
                          } else {
                            _selected.remove(task.displayId);
                          }
                        });
                      },
                    ),
                  for (final id
                      in _selected
                          .where(
                            (id) => !widget.tasks.any((t) => t.displayId == id),
                          )
                          .toList())
                    CheckboxListTile(
                      value: true,
                      title: Text(id),
                      onChanged: (_) => setState(() => _selected.remove(id)),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    ),
  );
}
