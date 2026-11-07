import '../../../tasks/domain/utils/task_column_label.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_model.dart';
import 'dashboard_widget_panel.dart'
    show dashboardObject, dashboardDone, flattenDashboardProjects;

class DashboardTaskListSheet extends StatefulWidget {
  const DashboardTaskListSheet({
    super.key,
    required this.title,
    required this.tasks,
    required this.projects,
    this.allocationFilters = false,
  });
  final String title;
  final List<Map<String, dynamic>> tasks;
  final List<ProjectModel> projects;
  final bool allocationFilters;
  @override
  State<DashboardTaskListSheet> createState() => _DashboardTaskListSheetState();
}

class _DashboardTaskListSheetState extends State<DashboardTaskListSheet> {
  final Map<String, String> _filters = {};
  bool _noDeadline(Map<String, dynamic> task) =>
      task['end'] == null || task['end'].toString().isEmpty;
  bool _noParticipant(Map<String, dynamic> task) =>
      (task['assigneeId']?.toString().isEmpty ?? true) &&
      !(task['assignees'] as List? ?? []).any(
        (a) => a is String
            ? a.isNotEmpty
            : (dashboardObject(a)['userId'] ??
                      dashboardObject(dashboardObject(a)['user'])['id']) !=
                  null,
      );
  String _deadline(Map<String, dynamic> task) {
    final end = DateTime.tryParse(task['end']?.toString() ?? '')?.toLocal();
    if (end == null) return 'Без срока';
    const months = [
      'янв.',
      'февр.',
      'мар.',
      'апр.',
      'мая',
      'июн.',
      'июл.',
      'авг.',
      'сент.',
      'окт.',
      'нояб.',
      'дек.',
    ];
    return '${!dashboardDone(task) && end.isBefore(DateTime.now()) ? 'Просрочено' : 'Срок'} · ${end.day} ${months[end.month - 1]}';
  }

  String _plural(int n, String one, String few, String many) =>
      '$n ${n % 10 == 1 && n % 100 != 11
          ? one
          : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)
          ? few
          : many}';
  Widget _pill(String text, {bool active = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: active ? AppColors.accent : const Color(0xFFF1F1EF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: active ? Colors.white : AppColors.muted,
      ),
    ),
  );
  Widget _filter(
    String projectId,
    String key,
    String label,
    IconData icon,
    int count,
  ) {
    final selected = (_filters[projectId] ?? 'all') == key;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: () => setState(() => _filters[projectId] = key),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: selected ? const Color(0xFF252537) : AppColors.muted,
          backgroundColor: selected ? Colors.white : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(
              color: selected ? AppColors.border : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            _pill('$count', active: selected),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final done = ((task['progress'] as num?) ?? 0) >= 100;
    final status = taskColumnLabel(
      task['status']?.toString() ?? '',
      name: task['columnName']?.toString(),
    );
    final end = DateTime.tryParse(task['end']?.toString() ?? '');
    final overdue =
        end != null && !dashboardDone(task) && end.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE3E3E1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, task['id']?.toString()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task['displayId']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      done ? LucideIcons.circleCheck : LucideIcons.circle,
                      size: 19,
                      color: done ? AppColors.accent : const Color(0xFFD8D8D5),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        task['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 7,
                  children: [
                    _meta(
                      overdue ? LucideIcons.circleAlert : LucideIcons.clock,
                      _deadline(task),
                      danger: overdue,
                    ),
                    if (_noParticipant(task))
                      _meta(LucideIcons.users, 'Без участника'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label, {bool danger = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 13,
        color: danger ? const Color(0xFFBE2A1D) : AppColors.muted,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: danger ? const Color(0xFFBE2A1D) : AppColors.muted,
          ),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final projects = flattenDashboardProjects(
      widget.projects,
    ).where((p) => widget.tasks.any((t) => t['projectId'] == p.id)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Задачи · ${widget.title}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_plural(projects.length, 'проект', 'проекта', 'проектов')} · ${_plural(widget.tasks.length, 'задача', 'задачи', 'задач')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (widget.tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Нет задач', textAlign: TextAlign.center),
                    ),
                  for (final project in projects)
                    Builder(
                      builder: (context) {
                        final tasks = widget.tasks
                            .where((t) => t['projectId'] == project.id)
                            .toList();
                        final filter = _filters[project.id] ?? 'all';
                        final visible = tasks
                            .where(
                              (t) => filter == 'deadline'
                                  ? _noDeadline(t)
                                  : filter == 'participant'
                                  ? _noParticipant(t)
                                  : true,
                            )
                            .toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      project.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Divider(
                                      height: 1,
                                      color: AppColors.border,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _pill('${tasks.length}'),
                                ],
                              ),
                            ),
                            if (widget.allocationFilters)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F6F5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        _filter(
                                          project.id,
                                          'all',
                                          'Все',
                                          LucideIcons.listChecks,
                                          tasks.length,
                                        ),
                                        _filter(
                                          project.id,
                                          'deadline',
                                          'Без срока',
                                          LucideIcons.clock,
                                          tasks.where(_noDeadline).length,
                                        ),
                                        _filter(
                                          project.id,
                                          'participant',
                                          'Без участника',
                                          LucideIcons.users,
                                          tasks.where(_noParticipant).length,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (visible.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Нет задач',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            for (final task in visible) _taskCard(task),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
