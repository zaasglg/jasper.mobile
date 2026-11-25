import 'package:jospar/core/localization/app_translations.dart';
import '../../../projects/domain/entities/project_model.dart';
import '../../../../core/widgets/app_widget_heading.dart';
import 'dashboard_widget_skeleton.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../data/mentions_read_storage.dart';
import 'dashboard_mentions_widget.dart';
import 'dashboard_resource_widget.dart';
import 'dashboard_activity_widget.dart';
import 'dashboard_scrum_widget.dart';
import 'dashboard_kpi_widget.dart';
import 'dashboard_team_widget.dart';
import 'dashboard_task_list_sheet.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../planner/domain/repositories/planner_repository.dart';
import '../../../planner/data/models/planner_item_model.dart';
import '../../domain/entities/dashboard_widget_slot.dart';
import '../../data/dashboard_repository_impl.dart';
import '../cubit/dashboard_layout_cubit.dart';

IconData dashboardWidgetIcon(String id) => switch (id) {
  'daily-motivation' => LucideIcons.sparkles500,
  'kpi-group' => LucideIcons.layoutDashboard500,
  'tasks-summary' => LucideIcons.listChecks500,
  'activity' => LucideIcons.clock500,
  'my-tasks' => LucideIcons.userCheck500,
  'team' => LucideIcons.users500,
  'mentions' => LucideIcons.atSign500,
  'calendar' => LucideIcons.calendarDays500,
  'resource' => LucideIcons.chartNoAxesCombined500,
  _ => LucideIcons.layoutDashboard500,
};
List<ProjectModel> flattenDashboardProjects(List<ProjectModel> projects) => [
  for (final project in projects) ...[
    project,
    ...flattenDashboardProjects(project.children),
  ],
];
Map<String, dynamic> dashboardObject(dynamic value) {
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return {};
    }
  }
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

bool dashboardDone(Map<String, dynamic> task) =>
    ((task['progress'] as num?) ?? 0) >= 100;

class DashboardWidgetPanel extends StatefulWidget {
  const DashboardWidgetPanel({
    required this.slot,
    this.revision = 0,
    required this.projects,
    required this.workspaceId,
    required this.userId,
    this.trailing,
    this.expandContent = false,
    super.key,
  });
  final DashboardWidgetSlot slot;
  final int revision;
  final List<ProjectModel> projects;
  final String workspaceId, userId;
  final Widget? trailing;
  final bool expandContent;
  @override
  State<DashboardWidgetPanel> createState() => _DashboardWidgetPanelState();
}

class _DashboardWidgetPanelState extends State<DashboardWidgetPanel> {
  late Future<dynamic> _future;
  DashboardLayoutCubit get cubit => context.read<DashboardLayoutCubit>();
  String get _dataKey => '${widget.slot.id}:${widget.workspaceId}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DashboardWidgetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.projects != widget.projects) {
      _load();
    }
  }

  void _load() {
    final kind = widget.slot.id;
    if (kind == 'calendar') {
      _future = cubit.data(_dataKey, () => sl<PlannerRepository>().load());
    } else if (['activity', 'mentions'].contains(kind)) {
      _future = cubit.data(_dataKey, () async {
        final result = await cubit.repository.widgetData(
          widget.workspaceId,
          kind,
        );
        if (kind == 'mentions') {
          return [
            ...DashboardRepositoryImpl.items(result).map(
              (e) => {
                ...e,
                'feedKind': 'mention',
                'feedId': 'mention:${e['id']}',
              },
            ),
            ...DashboardRepositoryImpl.items(
              await cubit.repository.widgetData(
                widget.workspaceId,
                'reactions',
              ),
            ).map(
              (e) => {
                ...e,
                'feedKind': 'reaction',
                'feedId': 'reaction:${e['id']}',
              },
            ),
          ];
        }
        return result;
      });
    } else {
      final ids = flattenDashboardProjects(
        widget.projects,
      ).map((e) => e.id).toList()..sort();
      _future = cubit.data(
        'tasks:${ids.join(',')}',
        () => cubit.repository.tasks(widget.workspaceId, ids),
      );
      if (kind == 'tasks-summary') {
        _future = Future.wait([
          _future,
          cubit.data(
            'scrum-metadata:${widget.workspaceId}',
            () => cubit.repository.widgetData(
              widget.workspaceId,
              'scrum-metadata',
            ),
          ),
        ]);
      }
      if (kind == 'team' || kind == 'daily-motivation') {
        final tasks = _future;
        _future = Future.wait([
          tasks,
          if (kind == 'team')
            cubit.data(
              'team-projects:${widget.workspaceId}',
              () => cubit.repository.widgetData(
                widget.workspaceId,
                'team-projects',
              ),
            ),
          cubit.data(
            '${kind == 'team' ? 'team' : 'recommendation-users'}:${widget.workspaceId}',
            () => cubit.repository.widgetData(
              widget.workspaceId,
              kind == 'team' ? 'team' : 'recommendation-users',
            ),
          ),
        ]);
      }
    }
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: AppColors.of(context).muted),
    ),
  );
  Future<void> _openTask(String id) async {
    await context.push('/tasks/${Uri.encodeComponent(id)}');
    if (mounted) cubit.refreshContent();
  }

  Widget _content(dynamic data) {
    final kind = widget.slot.id;
    if (kind == 'calendar') {
      final items =
          (data as List<PlannerItemModel>)
              .where(
                (e) =>
                    !e.completed &&
                    e.scheduledAt != null &&
                    !e.scheduledAt!.isBefore(
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
              )
              .toList()
            ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty) _empty('Нет запланированных дел'),
          for (final item in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.calendarDays, size: 16),
              title: Text(item.title, style: const TextStyle(fontSize: 12)),
              subtitle: Text(
                item.scheduledAt!.toLocal().toString().substring(0, 16),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.of(context).muted,
                ),
              ),
              onTap: () => context.go('/planner'),
            ),
          TextButton(
            onPressed: () => context.go('/planner'),
            child: Text(tr(context, 'Открыть ежедневник')),
          ),
        ],
      );
    }
    if (kind == 'daily-motivation') {
      final parts = data as List;
      final people = dashboardObject(parts[1]);
      final current = dashboardObject(people['currentUser']);
      final users = DashboardRepositoryImpl.items(
        people['users'],
      ).where((user) => user['id'] != current['id']).toList();
      final tasks = DashboardRepositoryImpl.items(parts[0]);
      final projectIds = flattenDashboardProjects(
        widget.projects,
      ).map((p) => p.id).toSet();
      final now = DateTime.now();
      final workload = users.map((user) {
        final assigned = tasks.where((task) {
          if (!projectIds.contains(task['projectId']) || dashboardDone(task)) {
            return false;
          }
          final assignees = task['assignees'];
          return assignees is List
              ? assignees.any(
                  (a) =>
                      dashboardObject(a)['userId'] == user['id'] ||
                      dashboardObject(dashboardObject(a)['user'])['id'] ==
                          user['id'],
                )
              : task['assigneeId'] == user['id'];
        }).toList();
        return (
          user: user,
          tasks: assigned,
          active: assigned.length,
          overdue: assigned.where((task) {
            final end = DateTime.tryParse(task['end']?.toString() ?? '');
            return end != null && end.isBefore(now);
          }).length,
        );
      }).toList();
      final average = workload.isEmpty
          ? 0.0
          : workload.fold<int>(0, (sum, p) => sum + p.active) / workload.length;
      final recommendations =
          workload
              .where(
                (p) =>
                    p.overdue >= 2 ||
                    (p.active >= 6 && p.active >= average * 1.5),
              )
              .toList()
            ..sort((a, b) => b.overdue.compareTo(a.overdue));
      if (recommendations.isEmpty) return _empty('Нет рекомендаций');
      return _AiRecommendations(
        overdueCount: {
          for (final rec in recommendations)
            for (final task in rec.tasks)
              if (DateTime.tryParse(
                    task['end']?.toString() ?? '',
                  )?.isBefore(now) ??
                  false)
                task['id']?.toString() ?? task,
        }.length,
        peopleCount: recommendations.length,
        items: [
          for (final rec in recommendations.take(3))
            (
              userId: rec.user['id']?.toString(),
              name: rec.user['name']?.toString() ?? '',
              avatarUrl:
                  (rec.user['avatarUrl'] ??
                          rec.user['avatar_url'] ??
                          rec.user['avatar'])
                      as String?,
              count: rec.overdue >= 2 ? rec.overdue : rec.active,
              isOverdue: rec.overdue >= 2,
              average: average.round(),
              onTap: () async {
                final id = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DashboardTaskListSheet(
                    title: tr(context, "Задачи · {p0}", {
                      'p0': rec.user['name'] ?? '',
                    }),
                    tasks: rec.tasks
                        .where(
                          (task) =>
                              rec.overdue < 2 ||
                              (DateTime.tryParse(
                                    task['end']?.toString() ?? '',
                                  )?.isBefore(now) ??
                                  false),
                        )
                        .toList(),
                    projects: widget.projects,
                  ),
                );
                if (id != null && mounted) await _openTask(id);
              },
            ),
        ],
      );
    }
    if (kind == 'activity') {
      return DashboardActivityWidget(
        key: ValueKey(
          '${widget.workspaceId}:${widget.userId}:${widget.slot.instanceId}',
        ),
        entries: DashboardRepositoryImpl.items(data),
        trailing: widget.trailing,
        onOpenTask: _openTask,
        loadCategory: (category) async => DashboardRepositoryImpl.items(
          await cubit.repository.widgetData(
            widget.workspaceId,
            'activity:$category',
          ),
        ),
      );
    }
    if (kind == 'mentions') {
      var entries = DashboardRepositoryImpl.items(data);
      final selected = (widget.slot.options.projectIds as List? ?? [])
          .map((e) => e.toString())
          .toSet();
      if (selected.isNotEmpty) {
        for (final project in flattenDashboardProjects(widget.projects)) {
          if (selected.contains(project.id)) {
            selected.addAll(
              flattenDashboardProjects(project.children).map((p) => p.id),
            );
          }
        }
        entries = entries
            .where((e) => selected.contains(e['projectId']))
            .toList();
      }
      final storage = sl.isRegistered<MentionsReadStorage>()
          ? sl<MentionsReadStorage>()
          : null;
      return DashboardMentionsWidget(
        key: ValueKey(
          '${widget.workspaceId}:${widget.userId}:${widget.slot.instanceId}',
        ),
        entries: entries,
        trailing: widget.trailing,
        onOpenTask: _openTask,
        loadRead: storage == null
            ? null
            : () => storage.load(widget.userId, widget.workspaceId),
        saveRead: storage == null
            ? null
            : (ids) => storage.save(widget.userId, widget.workspaceId, ids),
      );
    }
    if (kind == 'team') {
      final bundle = data as List;
      return DashboardTeamWidget(
        key: ValueKey('${widget.workspaceId}:${widget.slot.instanceId}'),
        people: DashboardRepositoryImpl.items(bundle[2]),
        tasks: DashboardRepositoryImpl.items(bundle[0]),
        projects: widget.projects,
        projectRecords: DashboardRepositoryImpl.items(bundle[1]),
        trailing: widget.trailing,
        initialProjectIds: (widget.slot.options.projectIds as List? ?? [])
            .map((id) => id.toString())
            .toList(),
        onOpenTask: (id) => _openTask(id),
      );
    }
    if (kind == 'tasks-summary') {
      final bundle = data as List;
      return DashboardScrumWidget(
        key: ValueKey('${widget.workspaceId}:${widget.slot.instanceId}'),
        tasks: DashboardRepositoryImpl.items(bundle[0]),
        metadata: dashboardObject(bundle[1]),
        projects: widget.projects,
        userId: widget.userId,
        initialMode: widget.slot.options.mode?.toString() ?? 'column',
        initialProjectIds: (widget.slot.options.projectIds as List? ?? [])
            .map((id) => id.toString())
            .toList(),
        trailing: widget.trailing,
        onOpenTask: _openTask,
      );
    }
    if (kind == 'resource') {
      return DashboardResourceWidget(
        key: ValueKey('${widget.workspaceId}:${widget.slot.instanceId}'),
        tasks: DashboardRepositoryImpl.items(data),
        projects: widget.projects,
        options: widget.slot.options,
        size: widget.slot.size,
        trailing: widget.trailing,
        onOpenTask: _openTask,
        onChanged: (changes) =>
            cubit.saveWidgetOptions(widget.slot.instanceId, changes),
      );
    }
    if (kind == 'kpi-group') {
      return DashboardKpiWidget(
        key: ValueKey('${widget.workspaceId}:${widget.slot.instanceId}'),
        tasks: DashboardRepositoryImpl.items(data),
        projects: widget.projects,
        initialProjectIds: (widget.slot.options.projectIds as List? ?? [])
            .map((id) => id.toString())
            .toList(),
        trailing: widget.trailing,
        onOpenTask: _openTask,
      );
    }
    return _empty('Нет данных');
  }

  @override
  Widget build(BuildContext context) => Container(
    height: widget.expandContent
        ? null
        : (widget.slot.height ??
                  ((widget.slot.definition?.rows ?? 14) * 24 - 16).toDouble())
              .clamp(
                ((widget.slot.definition?.rows ?? 14) * 24 - 16).toDouble(),
                900,
              )
              .toDouble(),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!WidgetCollapseScope.hidesHeading(context) &&
            widget.slot.id != 'team' &&
            widget.slot.id != 'kpi-group' &&
            widget.slot.id != 'tasks-summary' &&
            widget.slot.id != 'activity' &&
            widget.slot.id != 'resource' &&
            widget.slot.id != 'mentions')
          Padding(
            padding: widget.slot.id == 'daily-motivation'
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: AppWidgetHeading(
                    fullWidthToggle: widget.slot.id == 'daily-motivation',
                    icon: dashboardWidgetIcon(widget.slot.id),
                    iconAsset: widget.slot.id == 'daily-motivation'
                        ? 'assets/images/JBee.svg'
                        : null,
                    title: widget.slot.id == 'daily-motivation'
                        ? tr(context, 'AI рекомендации')
                        : widget.slot.definition?.title ?? widget.slot.id,
                    titleFontWeight: widget.slot.id == 'daily-motivation'
                        ? FontWeight.w600
                        : null,
                    iconColor: widget.slot.id == 'daily-motivation'
                        ? AppColors.accent
                        : AppColors.of(context).muted,
                  ),
                ),
                ?widget.trailing,
              ],
            ),
          ),
        if (!WidgetCollapseScope.hidesHeading(context) &&
            widget.slot.id != 'daily-motivation' &&
            widget.slot.id != 'team' &&
            widget.slot.id != 'kpi-group' &&
            widget.slot.id != 'tasks-summary' &&
            widget.slot.id != 'activity' &&
            widget.slot.id != 'resource' &&
            widget.slot.id != 'mentions')
          Divider(height: 1, color: AppColors.of(context).border),
        Flexible(
          fit: widget.expandContent ? FlexFit.loose : FlexFit.tight,
          child: FutureBuilder<dynamic>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(context, 'Не удалось загрузить виджет'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          cubit.retryData(_dataKey);
                          cubit.retryData('team:${widget.workspaceId}');
                          cubit.retryData(
                            'scrum-metadata:${widget.workspaceId}',
                          );
                          cubit.retryData(
                            'team-projects:${widget.workspaceId}',
                          );
                          cubit.retryData(
                            'recommendation-users:${widget.workspaceId}',
                          );
                          final ids = flattenDashboardProjects(
                            widget.projects,
                          ).map((e) => e.id).toList()..sort();
                          cubit.retryData('tasks:${ids.join(',')}');
                          setState(_load);
                        },
                        child: Text(tr(context, 'Повторить')),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return DashboardWidgetSkeleton(
                  kind: widget.slot.id,
                  showHeading:
                      !WidgetCollapseScope.hidesHeading(context) &&
                      [
                        'team',
                        'kpi-group',
                        'tasks-summary',
                        'activity',
                        'resource',
                        'mentions',
                      ].contains(widget.slot.id),
                );
              }
              return SingleChildScrollView(
                primary: false,
                physics: widget.expandContent
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: WidgetCollapseScope.hidesHeading(context)
                    ? const EdgeInsets.fromLTRB(18, 0, 18, 18)
                    : [
                        'team',
                        'kpi-group',
                        'tasks-summary',
                        'activity',
                        'resource',
                        'mentions',
                      ].contains(widget.slot.id)
                    ? const EdgeInsets.fromLTRB(18, 16, 18, 18)
                    : const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: _content(snapshot.data),
              );
            },
          ),
        ),
      ],
    ),
  );
}

typedef _AiRecommendationData = ({
  String? userId,
  String name,
  String? avatarUrl,
  int count,
  bool isOverdue,
  int average,
  VoidCallback onTap,
});

class _AiRecommendations extends StatelessWidget {
  const _AiRecommendations({
    required this.items,
    required this.overdueCount,
    required this.peopleCount,
  });

  final List<_AiRecommendationData> items;
  final int overdueCount;
  final int peopleCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'С чего начать сегодня'),
          style: AppTypography.title(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr(context, 'Приоритетные действия по текущим задачам'),
          style: AppTypography.caption(
            context,
          )?.copyWith(color: AppColors.of(context).muted),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < items.length; index++) ...[
          _AiRecommendationCard(item: items[index]),
          if (index != items.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _AiRecommendationCard extends StatelessWidget {
  const _AiRecommendationCard({required this.item});

  final _AiRecommendationData item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = item.isOverdue ? colors.error : colors.primary;
    final status = item.isOverdue
        ? '${item.count} ${_taskWord(item.count, short: false)} с истёкшим сроком. Проверьте сроки и приоритеты.'
        : '${item.count} активных задач при средней нагрузке ${item.average}. Проверьте, нужна ли помощь.';

    return Semantics(
      container: true,
      label: tr(context, "{p0}. {p1}. Открыть задачи", {
        'p0': item.name,
        'p1': status,
      }),
      button: true,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.smMd),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  size: AppSpacing.lg + AppSpacing.sm,
                  userId: item.userId,
                  name: item.name,
                  avatarUrl: item.avatarUrl,
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.isOverdue
                            ? tr(context, 'Проверьте просроченные задачи')
                            : tr(context, 'Оцените распределение задач'),
                        style: AppTypography.body(context)?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(item.name, style: AppTypography.body(context)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        status,
                        style: AppTypography.caption(
                          context,
                        )?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        tr(context, 'Посмотреть задачи →'),
                        style: AppTypography.caption(context)?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  item.isOverdue
                      ? LucideIcons.triangleAlert
                      : LucideIcons.gauge,
                  size: 18,
                  color: tone,
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _taskWord(int value, {required bool short}) {
    if (short) return 'просрочено';
    final mod100 = value % 100;
    final mod10 = value % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'задач';
    if (mod10 == 1) return 'задача';
    if (mod10 >= 2 && mod10 <= 4) return 'задачи';
    return 'задач';
  }
}
