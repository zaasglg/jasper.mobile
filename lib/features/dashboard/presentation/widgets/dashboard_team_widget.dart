import 'package:jospar/core/localization/app_translations.dart';
import '../../../projects/domain/entities/project_model.dart';
import '../../../../core/widgets/app_widget_heading.dart';
import 'dashboard_expandable_content.dart';
import '../../../tasks/domain/utils/task_column_label.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'dashboard_widget_panel.dart' show dashboardObject, dashboardDone;

abstract final class _TeamTypography {
  static TextStyle name(BuildContext context) => TextStyle(
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.of(context).ink,
  );
  static const detail = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: Color(0xFF71717A),
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const column = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: Color(0xFF71717A),
  );
  static TextStyle number(BuildContext context) => TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.of(context).ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle percentage(BuildContext context) => TextStyle(
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.of(context).ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class DashboardTeamWidget extends StatefulWidget {
  const DashboardTeamWidget({
    super.key,
    required this.people,
    required this.tasks,
    required this.projects,
    required this.onOpenTask,
    this.trailing,
    this.projectRecords = const [],
    this.initialProjectIds = const [],
  });
  final Widget? trailing;
  final List<Map<String, dynamic>> people, tasks, projectRecords;
  final List<ProjectModel> projects;
  final List<String> initialProjectIds;
  final Future<void> Function(String) onOpenTask;
  @override
  State<DashboardTeamWidget> createState() => _DashboardTeamWidgetState();
}

class _DashboardTeamWidgetState extends State<DashboardTeamWidget> {
  String _view = 'cards';
  late Set<String> _selected = widget.initialProjectIds.toSet();
  Set<String> get _scope {
    final result = <String>{};
    void visit(ProjectModel p, bool included) {
      included = included || _selected.isEmpty || _selected.contains(p.id);
      if (included) result.add(p.id);
      for (final child in p.children) {
        visit(child, included);
      }
    }

    for (final p in widget.projects) {
      visit(p, false);
    }
    return result;
  }

  List<ProjectModel> get _projects {
    List<ProjectModel> flatten(List<ProjectModel> projects) => [
      for (final p in projects) ...[p, ...flatten(p.children)],
    ];
    return flatten(
      widget.projects,
    ).where((p) => _scope.contains(p.id)).toList();
  }

  bool _overdue(Map<String, dynamic> t) =>
      !dashboardDone(t) &&
      (DateTime.tryParse(
            t['end']?.toString() ?? '',
          )?.isBefore(DateTime.now()) ??
          false);
  bool _assigned(Map<String, dynamic> task, String id) {
    final list = task['assignees'];
    return list is List
        ? list.any(
            (a) => a is String
                ? a == id
                : (dashboardObject(a)['userId'] ??
                          dashboardObject(dashboardObject(a)['user'])['id']) ==
                      id,
          )
        : task['assigneeId'] == id;
  }

  List<Map<String, dynamic>> _tasks(String id) =>
      widget.tasks
          .where(
            (t) =>
                t['archived'] != true &&
                _scope.contains(t['projectId']) &&
                _assigned(t, id),
          )
          .toList()
        ..sort((a, b) {
          final overdue = (_overdue(b) ? 1 : 0).compareTo(_overdue(a) ? 1 : 0);
          return overdue != 0
              ? overdue
              : (DateTime.tryParse(a['end']?.toString() ?? '') ??
                        DateTime(9999))
                    .compareTo(
                      DateTime.tryParse(b['end']?.toString() ?? '') ??
                          DateTime(9999),
                    );
        });
  Set<String> _memberProjects(String id, List<Map<String, dynamic>> tasks) {
    final ids = tasks.map((t) => t['projectId'].toString()).toSet();
    void visit(Map<String, dynamic> p) {
      if (_scope.contains(p['id']) &&
          (p['members'] as List? ?? []).any(
            (m) =>
                (dashboardObject(m)['userId'] ??
                    dashboardObject(dashboardObject(m)['user'])['id'] ??
                    dashboardObject(m)['id']) ==
                id,
          )) {
        ids.add(p['id'].toString());
      }
      for (final child in p['children'] as List? ?? []) {
        visit(dashboardObject(child));
      }
    }

    for (final p in widget.projectRecords) {
      visit(p);
    }
    return ids;
  }

  double _listColumnWidth(BuildContext context, String label, double minimum) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.merge(_TeamTypography.column),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + 8;
    painter.dispose();
    return width < minimum ? minimum : width.ceilToDouble();
  }

  Widget _avatar(Map<String, dynamic> user, double size) => UserAvatar(
    size: size,
    userId: user['id']?.toString(),
    name: user['name']?.toString() ?? '',
    avatarUrl:
        (user['avatarUrl'] ?? user['avatar_url'] ?? user['avatar']) as String?,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : const Color(0xFFF6F6F5),
    foregroundColor: AppColors.of(context).muted,
  );
  Widget _badge(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFBB291E),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.triangleAlert, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
  String _plural(int n, String one, String few, String many) =>
      '$n ${n % 10 == 1 && n % 100 != 11
          ? one
          : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)
          ? few
          : many}';
  Widget _metric(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.of(context).muted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _TeamTypography.detail,
        ),
      ),
    ],
  );
  Widget _timing(List<Map<String, dynamic>> tasks) {
    final running = tasks.any(
      (t) => DateTime.tryParse(t['timerStartedAt']?.toString() ?? '') != null,
    );
    final has =
        running ||
        tasks.any(
          (t) =>
              ((t['timerElapsedMs'] as num?) ?? 0) > 0 ||
              ((dashboardObject(t['detail'])['estimateMinutes'] as num?) ?? 0) >
                  0,
        );
    return has
        ? Icon(
            LucideIcons.clock,
            size: 14,
            color: running
                ? const Color(0xFF19744C)
                : AppColors.of(context).muted,
          )
        : const SizedBox.shrink();
  }

  Future<void> _open(
    Map<String, dynamic> user,
    List<Map<String, dynamic>> tasks,
    Set<String> projects,
  ) async {
    final taskId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).canvas,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, "Задачи · {p0}", {
                              'p0': user['name'] ?? 'Участник',
                            }),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr(
                              context,
                              "{p0} проектов · {p1} задач · {p2} просрочено",
                              {
                                'p0': projects.length,
                                'p1': tasks.length,
                                'p2': tasks.where(_overdue).length,
                              },
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.of(context).muted,
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
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (tasks.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          tr(context, 'Нет назначенных задач'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final project in _projects.where(
                      (p) => projects.contains(p.id),
                    )) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '${project.name.toUpperCase()} · ${tasks.where((t) => t['projectId'] == project.id).length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.of(context).muted,
                          ),
                        ),
                      ),
                      for (final task in tasks.where(
                        (t) => t['projectId'] == project.id,
                      ))
                        _taskCard(context, task),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (taskId != null && mounted) await widget.onOpenTask(taskId);
  }

  Widget _taskCard(BuildContext context, Map<String, dynamic> task) {
    final end = DateTime.tryParse(task['end']?.toString() ?? '')?.toLocal();
    final plan =
        ((dashboardObject(task['detail'])['estimateMinutes'] as num?) ?? 0)
            .toInt();
    final start = DateTime.tryParse(task['timerStartedAt']?.toString() ?? '');
    final elapsed =
        (((task['timerElapsedMs'] as num?) ?? 0) +
                (start == null
                    ? 0
                    : DateTime.now().difference(start).inMilliseconds))
            .clamp(0, double.infinity) ~/
        60000;
    final status = taskColumnLabel(
      task['status']?.toString() ?? '',
      name: task['columnName']?.toString(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.of(context).canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.of(context).border),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.of(context).muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      dashboardDone(task)
                          ? LucideIcons.circleCheck
                          : LucideIcons.circle,
                      size: 17,
                      color: AppColors.of(context).muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  end == null
                      ? tr(context, 'Без срока')
                      : '${_overdue(task) ? 'Просрочено' : 'Срок'} · ${end.day}.${end.month.toString().padLeft(2, '0')}.${end.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _overdue(task)
                        ? const Color(0xFFBB291E)
                        : AppColors.of(context).muted,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Text(
                  tr(context, "План: {p0} ч {p1} мин · Факт: {p2} ч {p3} мин", {
                    'p0': plan ~/ 60,
                    'p1': plan % 60,
                    'p2': elapsed ~/ 60,
                    'p3': elapsed % 60,
                  }),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _filter() async {
    final selected = {..._selected};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.of(context).canvas,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(context, 'Проекты'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: Text(tr(context, 'Все проекты')),
                          selected: selected.isEmpty,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          value: selected.isEmpty,
                          onChanged: (_) => setSheetState(selected.clear),
                        ),
                        for (final p in widget.projects.expand(
                          (p) => [p, ...p.children],
                        ))
                          CheckboxListTile(
                            title: Text(p.name),
                            selected: selected.contains(p.id),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            value: selected.contains(p.id),
                            onChanged: (value) => setSheetState(
                              () => value == true
                                  ? selected.add(p.id)
                                  : selected.remove(p.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: Text(tr(context, 'Готово')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _selected = result);
  }

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final people = widget.people
        .map(
          (p) => {
            ...dashboardObject(p['user'] ?? p),
            'id': dashboardObject(p['user'] ?? p)['id'] ?? p['userId'],
          },
        )
        .where((p) => p['id'] != null && seen.add(p['id'].toString()))
        .where(
          (p) =>
              _selected.isEmpty ||
              _memberProjects(
                p['id'].toString(),
                _tasks(p['id'].toString()),
              ).isNotEmpty,
        )
        .toList();
    final visiblePeople = DashboardPreviewScope.limit(context, people);
    final headingScope = context
        .dependOnInheritedWidgetOfExactType<WidgetCollapseScope>();
    if (headingScope?.onMemberCountChanged != null &&
        headingScope!.memberCount != people.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) headingScope.onMemberCountChanged?.call(people.length);
      });
    }

    return LayoutBuilder(
      builder: (context, headerConstraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!WidgetCollapseScope.hidesHeading(context)) ...[
              AppWidgetHeading(
                icon: LucideIcons.users,
                title: tr(context, 'Команда'),
                memberCount: people.length,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _filter,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                      foregroundColor: AppColors.of(context).muted,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _selected.isEmpty
                                ? tr(context, 'Все проекты')
                                : tr(context, "Проекты: {p0}", {
                                    'p0': _selected.length,
                                  }),
                            overflow: TextOverflow.ellipsis,
                            style: _TeamTypography.detail,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(LucideIcons.chevronDown, size: 14),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDEDEDC)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(2),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in [
                        (
                          id: 'cards',
                          icon: LucideIcons.layoutGrid,
                          label: 'Карточки',
                        ),
                        (id: 'list', icon: LucideIcons.list, label: 'Список'),
                        (
                          id: 'rings',
                          icon: LucideIcons.circleDashed,
                          label: 'Эффективность',
                        ),
                      ])
                        Semantics(
                          selected: _view == entry.id,
                          button: true,
                          label: entry.label,
                          child: Tooltip(
                            message: entry.label,
                            excludeFromSemantics: true,
                            child: Material(
                              color: _view == entry.id
                                  ? AppColors.accent.withValues(alpha: 0.10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                key: ValueKey('team-view-${entry.id}'),
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setState(() => _view = entry.id),
                                child: SizedBox.square(
                                  dimension: 30,
                                  child: Icon(
                                    entry.icon,
                                    size: 15,
                                    color: _view == entry.id
                                        ? AppColors.accent
                                        : AppColors.of(context).muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ?widget.trailing,
              ],
            ),
            const SizedBox(height: 8),
            if (people.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  tr(context, 'Нет участников'),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_view == 'list')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Участник'),
                        style: _TeamTypography.column,
                      ),
                    ),
                    SizedBox(
                      width: _listColumnWidth(context, 'Проект.', 52),
                      child: Text(
                        tr(context, 'Проект.'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: _TeamTypography.column,
                      ),
                    ),
                    SizedBox(
                      width: _listColumnWidth(context, 'Задачи', 48),
                      child: Text(
                        tr(context, 'Задачи'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: _TeamTypography.column,
                      ),
                    ),
                    SizedBox(
                      width: _listColumnWidth(context, 'Проср.', 52),
                      child: Text(
                        tr(context, 'Проср.'),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: _TeamTypography.column,
                      ),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = _view == 'list' ? 1 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                if (_view == 'cards') {
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < visiblePeople.length;
                        index += 2
                      ) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _person(visiblePeople[index])),
                            const SizedBox(width: 16),
                            Expanded(
                              child: index + 1 < visiblePeople.length
                                  ? _person(visiblePeople[index + 1])
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        if (index + 2 < visiblePeople.length)
                          const Divider(height: 1, color: Color(0xFFF1F1F3)),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: 12,
                  children: [
                    for (final user in visiblePeople)
                      SizedBox(width: width, child: _person(user)),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _person(Map<String, dynamic> user) {
    final tasks = _tasks(user['id'].toString());
    final projects = _memberProjects(user['id'].toString(), tasks);
    final done = tasks.where(dashboardDone).length;
    final overdue = tasks.where(_overdue).length;
    final name = Text(
      user['name']?.toString() ?? 'Участник',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _TeamTypography.name(context),
    );
    return InkWell(
      onTap: () => _open(user, tasks, projects),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: _view == 'cards' ? 12 : 16),
        decoration: _view == 'cards'
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F1F3))),
              ),
        child: _view == 'cards'
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _avatar(user, 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user['name']?.toString() ?? 'Участник',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _TeamTypography.name(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 4,
                      children: [
                        _metric(
                          LucideIcons.folderKanban,
                          _plural(
                            projects.length,
                            'проект',
                            'проекта',
                            'проектов',
                          ),
                        ),
                        _metric(
                          LucideIcons.listChecks,
                          _plural(tasks.length, 'задача', 'задачи', 'задач'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 24),
                    child: Row(
                      children: [
                        if (overdue > 0)
                          Tooltip(
                            message: tr(context, "Просрочено задач: {p0}", {
                              'p0': overdue,
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBEEEC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.triangleAlert,
                                    size: 10,
                                    color: Color(0xFFBB291F),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr(context, "{p0} проср.", {'p0': overdue}),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      color: Color(0xFFBB291F),
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        _timing(tasks),
                      ],
                    ),
                  ),
                ],
              )
            : _view == 'rings'
            ? Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: tasks.isEmpty ? 0 : done / tasks.length,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            color: const Color(0xFF19744C),
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow
                                : const Color(0xFFF5F5F4),
                          ),
                        ),
                        Text(
                          '${tasks.isEmpty ? 0 : (100 * done / tasks.length).round()}%',
                          style: _TeamTypography.percentage(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _avatar(user, 24),
                      const SizedBox(width: 8),
                      Flexible(child: name),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, "{p0} из {p1} завершено", {
                      'p0': done,
                      'p1': tasks.length,
                    }),
                    style: _TeamTypography.detail,
                  ),
                ],
              )
            : Row(
                children: [
                  _avatar(user, _view == 'list' ? 26 : 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _view == 'list'
                        ? name
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              name,
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _metric(
                                    LucideIcons.folderKanban,
                                    _plural(
                                      projects.length,
                                      'проект',
                                      'проекта',
                                      'проектов',
                                    ),
                                  ),
                                  _metric(
                                    LucideIcons.listChecks,
                                    _plural(
                                      tasks.length,
                                      'задача',
                                      'задачи',
                                      'задач',
                                    ),
                                  ),
                                  _timing(tasks),
                                  if (overdue > 0) _badge(overdue),
                                ],
                              ),
                            ],
                          ),
                  ),
                  if (_view == 'list') ...[
                    SizedBox(
                      width: _listColumnWidth(context, 'Проект.', 52),
                      child: Text(
                        '${projects.length}',
                        textAlign: TextAlign.center,
                        style: _TeamTypography.number(context),
                      ),
                    ),
                    SizedBox(
                      width: _listColumnWidth(context, 'Задачи', 48),
                      child: Text(
                        '${tasks.length}',
                        textAlign: TextAlign.center,
                        style: _TeamTypography.number(context),
                      ),
                    ),
                    SizedBox(
                      width: _listColumnWidth(context, 'Проср.', 52),
                      child: Center(
                        child: overdue > 0
                            ? _badge(overdue)
                            : Text(
                                '—',
                                style: TextStyle(
                                  color: AppColors.of(context).muted,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
