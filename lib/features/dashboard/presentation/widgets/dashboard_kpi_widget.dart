import 'package:jospar/core/localization/app_translations.dart';
import '../../../projects/domain/entities/project_model.dart';
import '../../../../core/widgets/app_widget_heading.dart';
import 'dashboard_selector.dart';
import 'dashboard_task_list_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import 'dashboard_widget_panel.dart'
    show dashboardDone, dashboardObject, flattenDashboardProjects;

class DashboardKpiWidget extends StatefulWidget {
  const DashboardKpiWidget({
    super.key,
    required this.tasks,
    required this.projects,
    required this.onOpenTask,
    this.initialProjectIds = const [],
    this.trailing,
  });
  final List<Map<String, dynamic>> tasks;
  final List<ProjectModel> projects;
  final List<String> initialProjectIds;
  final Future<void> Function(String) onOpenTask;
  final Widget? trailing;
  @override
  State<DashboardKpiWidget> createState() => _DashboardKpiWidgetState();
}

class _DashboardKpiWidgetState extends State<DashboardKpiWidget> {
  late Set<String> _selected = widget.initialProjectIds.toSet();
  List<ProjectModel> get _projects => _selected.isEmpty
      ? widget.projects
      : flattenDashboardProjects(
          widget.projects,
        ).where((p) => _selected.contains(p.id)).toList();
  Set<String> get _scope => _selected.isEmpty
      ? flattenDashboardProjects(widget.projects).map((p) => p.id).toSet()
      : flattenDashboardProjects(widget.projects)
            .where((p) => _selected.contains(p.id))
            .expand((p) => flattenDashboardProjects([p]))
            .map((p) => p.id)
            .toSet();
  List<Map<String, dynamic>> get _tasks => widget.tasks
      .where((t) => t['archived'] != true && _scope.contains(t['projectId']))
      .toList();
  bool _overdue(Map<String, dynamic> t) =>
      !dashboardDone(t) &&
      (DateTime.tryParse(
            t['end']?.toString() ?? '',
          )?.isBefore(DateTime.now()) ??
          false);
  bool _unallocated(Map<String, dynamic> t) =>
      (t['end']?.toString().isEmpty ?? true) ||
      ((t['assigneeId']?.toString().isEmpty ?? true) &&
          !(t['assignees'] as List? ?? []).any(
            (a) => a is String
                ? a.isNotEmpty
                : (dashboardObject(a)['userId'] ??
                          dashboardObject(dashboardObject(a)['user'])['id']) !=
                      null,
          ));
  Future<void> _showTasks(
    String title,
    List<Map<String, dynamic>> tasks,
  ) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.of(context).canvas,
      builder: (context) => DashboardTaskListSheet(
        title: title,
        tasks: tasks,
        projects: widget.projects,
        allocationFilters:
            title == 'Не распределено' ||
            title == tr(context, 'Не распределено'),
      ),
    );
    if (id != null && mounted) await widget.onOpenTask(id);
  }

  Widget _total(String label, int count, String caption, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Widget _status(
    String title,
    IconData icon,
    List<Map<String, dynamic>> tasks, {
    bool danger = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: danger ? const Color(0xFFFAEEEC) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: danger ? const Color(0xFFF0C5C0) : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showTasks(title, tasks),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: danger
                    ? const Color(0xFFBE2A1D)
                    : AppColors.of(context).muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: danger
                        ? const Color(0xFFBE2A1D)
                        : AppColors.of(context).muted,
                  ),
                ),
              ),
              Text(
                '${tasks.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: danger
                      ? const Color(0xFFBE2A1D)
                      : AppColors.of(context).ink,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: danger
                    ? const Color(0xFFBE2A1D)
                    : AppColors.of(context).muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final done = tasks.where(dashboardDone).toList();
    final overdue = tasks.where(_overdue).toList();
    final unallocated = tasks
        .where((t) => !dashboardDone(t) && !_overdue(t) && _unallocated(t))
        .toList();
    final active = tasks
        .where((t) => !dashboardDone(t) && !_overdue(t) && !_unallocated(t))
        .toList();
    final totals = Row(
      children: [
        _total(
          tr(context, 'Проекты'),
          _selected.isEmpty ? widget.projects.length : _scope.length,
          tr(context, 'всего проектов'),
          () => context.go('/projects'),
        ),
        const SizedBox(width: 20),
        _total(
          tr(context, 'Задачи'),
          tasks.length,
          tr(context, 'всего задач'),
          () => _showTasks(tr(context, 'Все задачи'), tasks),
        ),
      ],
    );
    final statuses = Column(
      children: [
        _status(
          tr(context, 'Не распределено'),
          LucideIcons.circleDot,
          unallocated,
        ),
        _status(tr(context, 'В работе'), LucideIcons.listChecks, active),
        _status(tr(context, 'Завершено'), LucideIcons.circleCheck, done),
        _status(
          tr(context, 'Просрочено'),
          LucideIcons.triangleAlert,
          overdue,
          danger: true,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!WidgetCollapseScope.hidesHeading(context)) ...[
          AppWidgetHeading(
            icon: LucideIcons.layout,
            title: tr(context, 'Общие данные'),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: DashboardSelector<String>(
                tooltip: tr(context, 'Фильтр проектов'),
                onSelected: (id) =>
                    setState(() => _selected = id.isEmpty ? {} : {id}),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: '',
                    checked: _selected.isEmpty,
                    child: Text(tr(context, 'Все проекты')),
                  ),
                  for (final p in flattenDashboardProjects(widget.projects))
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
                          _selected.isEmpty
                              ? tr(context, 'Все проекты')
                              : _selected.length == 1
                              ? flattenDashboardProjects(widget.projects)
                                        .where((p) => _selected.contains(p.id))
                                        .map((p) => p.name)
                                        .firstOrNull ??
                                    'Все проекты'
                              : tr(context, "Проектов: {p0}", {
                                  'p0': _selected.length,
                                }),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.of(context).muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: AppColors.of(context).muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 600
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: totals),
                    Container(
                      height: 180,
                      width: 1,
                      color: AppColors.of(context).border,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    Expanded(child: statuses),
                  ],
                )
              : Column(
                  children: [
                    totals,
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),
                    statuses,
                  ],
                ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),
        for (final p in _projects)
          Builder(
            builder: (context) {
              final ids = flattenDashboardProjects([
                p,
              ]).map((p) => p.id).toSet();
              final projectTasks = tasks
                  .where((t) => ids.contains(t['projectId']))
                  .toList();
              final progress = projectTasks.isEmpty
                  ? 0.0
                  : projectTasks.where(dashboardDone).length /
                        projectTasks.length;
              final hue = p.id.codeUnits.fold<int>(0, (sum, c) => sum + c) % 3;
              final color = [
                const Color(0xFFAE3634),
                const Color(0xFF87982A),
                const Color(0xFF269652),
              ][hue];
              return InkWell(
                onTap: () => _showTasks(p.name, projectTasks),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F1F3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          (p.code.isEmpty
                                  ? (p.name.isEmpty ? '?' : p.name)
                                  : p.code)
                              .characters
                              .first
                              .toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.of(context).muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                color: AppColors.accent,
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLow
                                    : const Color(0xFFF5F5F4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
