import '../../../../core/widgets/app_widget_heading.dart';
import 'dashboard_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_model.dart';
import 'dashboard_task_list_sheet.dart';
import 'dashboard_widget_panel.dart'
    show dashboardObject, dashboardDone, flattenDashboardProjects;

class DashboardScrumWidget extends StatefulWidget {
  const DashboardScrumWidget({
    super.key,
    required this.tasks,
    required this.metadata,
    required this.projects,
    required this.userId,
    required this.onOpenTask,
    this.initialProjectIds = const [],
    this.initialMode = 'column',
    this.trailing,
  });
  final List<Map<String, dynamic>> tasks;
  final Map<String, dynamic> metadata;
  final List<ProjectModel> projects;
  final String userId, initialMode;
  final List<String> initialProjectIds;
  final Widget? trailing;
  final Future<void> Function(String) onOpenTask;
  @override
  State<DashboardScrumWidget> createState() => _DashboardScrumWidgetState();
}

class _DashboardScrumWidgetState extends State<DashboardScrumWidget> {
  late String _mode = widget.initialMode;
  late Set<String> _selected = _initialSelection();
  Set<String> _initialSelection() {
    if (widget.initialProjectIds.contains('all')) return {'all'};
    final ids = flattenDashboardProjects(
      widget.projects,
    ).map((p) => p.id).toSet();
    final valid = widget.initialProjectIds.where(ids.contains).toSet();
    return valid.isNotEmpty
        ? valid
        : {if (widget.projects.isNotEmpty) widget.projects.first.id};
  }

  bool _mine = false;
  Set<String> get _scope => flattenDashboardProjects(widget.projects)
      .where((p) => _selected.contains('all') || _selected.contains(p.id))
      .expand((p) => flattenDashboardProjects([p]))
      .map((p) => p.id)
      .toSet();
  List<Map<String, dynamic>> get _tasks => widget.tasks
      .where(
        (t) =>
            t['archived'] != true &&
            _scope.contains(t['projectId']) &&
            (!_mine ||
                t['assigneeId'] == widget.userId ||
                (t['assignees'] as List? ?? []).any(
                  (a) => a is String
                      ? a == widget.userId
                      : (dashboardObject(a)['userId'] ??
                                dashboardObject(
                                  dashboardObject(a)['user'],
                                )['id']) ==
                            widget.userId,
                )),
      )
      .toList();
  Color _color(dynamic raw) {
    final hex = raw?.toString().replaceFirst('#', '') ?? '';
    return Color(
      int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16) ?? 0xFF6D5FE0,
    );
  }

  Future<void> _open(String title, List<Map<String, dynamic>> tasks) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => DashboardTaskListSheet(
        title: title,
        tasks: tasks,
        projects: widget.projects,
      ),
    );
    if (id != null && mounted) await widget.onOpenTask(id);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final done = tasks
        .where((t) => t['status']?.toString().toUpperCase() == 'DONE')
        .length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    final overdue = tasks
        .where(
          (t) =>
              !dashboardDone(t) &&
              (DateTime.tryParse(
                    t['end']?.toString() ?? '',
                  )?.isBefore(DateTime.now()) ??
                  false),
        )
        .toList();
    final groups =
        <
          String,
          ({String label, Color color, List<Map<String, dynamic>> tasks})
        >{};
    for (final projectId in _scope) {
      var definitions =
          (widget.metadata[_mode == 'epic' ? 'epics' : 'columns'] as List? ??
                  [])
              .map(dashboardObject)
              .where((g) => g['projectId'] == projectId)
              .toList();
      if (_mode == 'column' && definitions.isEmpty) {
        definitions = [
          {'name': 'Бэклог', 'statusMap': 'BACKLOG', 'color': '#EC168C'},
          {'name': 'К работе', 'statusMap': 'TODO', 'color': '#D88C3E'},
          {'name': 'В работе', 'statusMap': 'PROGRESS', 'color': '#6D5FE0'},
          {'name': 'Готово', 'statusMap': 'DONE', 'color': '#10B981'},
        ];
      }
      definitions.sort(
        (a, b) =>
            ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0),
      );
      for (final definition in definitions) {
        final label = definition['name']?.toString().trim() ?? '';
        if (label.isEmpty) continue;
        final matching = tasks
            .where(
              (t) =>
                  t['projectId'] == projectId &&
                  (_mode == 'column'
                      ? t['status']?.toString().toUpperCase() ==
                            definition['statusMap']?.toString().toUpperCase()
                      : (t['epics'] as List? ?? []).any(
                          (e) =>
                              (dashboardObject(e)['epicId'] ??
                                  dashboardObject(
                                    dashboardObject(e)['epic'],
                                  )['id'] ??
                                  dashboardObject(e)['id']) ==
                              definition['id'],
                        )),
            )
            .toList();
        final key = label.toLowerCase();
        final existing = groups[key];
        groups[key] = (
          label: existing?.label ?? label,
          color: existing?.color ?? _color(definition['color']),
          tasks: [...?existing?.tasks, ...matching],
        );
      }
    }
    final flat = flattenDashboardProjects(widget.projects);
    final label = _selected.contains('all')
        ? 'Все проекты'
        : _selected.length == 1
        ? flat
                  .where((p) => _selected.contains(p.id))
                  .map((p) => p.name)
                  .firstOrNull ??
              'Выберите проект'
        : 'Проектов: ${_selected.length}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AppWidgetHeading(
              icon: LucideIcons.listChecks,
              title: 'Скрам',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DashboardSelector<String>(
                tooltip: 'Проект скрама',
                onSelected: (id) => setState(() => _selected = {id}),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: 'all',
                    checked: _selected.contains('all'),
                    child: const Text('Все проекты'),
                  ),
                  for (final p in flat)
                    CheckedPopupMenuItem(
                      value: p.id,
                      checked: _selected.contains(p.id),
                      child: Text(p.name),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            DashboardSelector<String>(
              tooltip: 'Группировка скрама',
              onSelected: (mode) => setState(() => _mode = mode),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'column',
                  checked: _mode == 'column',
                  child: const Text('Колонка'),
                ),
                CheckedPopupMenuItem(
                  value: 'epic',
                  checked: _mode == 'epic',
                  child: const Text('Эпик'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Text(
                      _mode == 'epic' ? 'Эпик' : 'Колонка',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.chevronDown,
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
        InkWell(
          onTap: widget.userId.isEmpty
              ? null
              : () => setState(() => _mine = !_mine),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 24,
                  child: Checkbox(
                    value: _mine,
                    onChanged: widget.userId.isEmpty
                        ? null
                        : (v) => setState(() => _mine = v ?? false),
                    side: const BorderSide(color: Color(0xFFD9D9D6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Только мои задачи',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              '$done из ${tasks.length} выполнено',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: AppColors.accent,
            backgroundColor: const Color(0xFFF5F5F4),
          ),
        ),
        const SizedBox(height: 14),
        if (widget.projects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Нет проектов', textAlign: TextAlign.center),
          ),
        if (groups.isEmpty && widget.projects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _mode == 'epic' ? 'Нет эпиков' : 'Нет колонок',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        for (final group in groups.values)
          InkWell(
            onTap: () => _open(group.label, group.tasks),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: group.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF606079),
                      ),
                    ),
                  ),
                  Text(
                    '${group.tasks.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (overdue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Material(
              color: const Color(0xFFFAEEEC),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _open('Просрочено', overdue),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.triangleAlert,
                        size: 15,
                        color: Color(0xFFBE2A1D),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${overdue.length} задач просрочено',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFBE2A1D),
                          ),
                        ),
                      ),
                      const Icon(
                        LucideIcons.arrowRight,
                        size: 16,
                        color: Color(0xFFBE2A1D),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
