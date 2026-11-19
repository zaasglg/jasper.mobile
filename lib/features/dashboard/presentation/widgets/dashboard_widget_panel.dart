import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_widget_heading.dart';
import 'dashboard_widget_skeleton.dart';
import '../../../../core/theme/dashboard_surface.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../data/mentions_read_storage.dart';
import 'dashboard_mentions_widget.dart';
import 'dashboard_resource_widget.dart';
import 'dashboard_activity_widget.dart';
import 'dashboard_scrum_widget.dart';
import 'dashboard_kpi_widget.dart';
import 'dashboard_team_widget.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'dashboard_task_map.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../planner/domain/repositories/planner_repository.dart';
import '../../../planner/data/models/planner_item_model.dart';
import '../../../storage/presentation/storage_file_screen.dart';
import '../../data/dashboard_layout.dart';
import '../../data/dashboard_repository_impl.dart';
import '../cubit/dashboard_layout_cubit.dart';

IconData dashboardWidgetIcon(String id) => switch (id) {
  'daily-motivation' => LucideIcons.sparkles,
  'kpi-group' => LucideIcons.chartColumn,
  'tasks-summary' => LucideIcons.listChecks,
  'activity' => LucideIcons.history,
  'my-tasks' => LucideIcons.userCheck,
  'team' => LucideIcons.users,
  'mentions' => LucideIcons.atSign,
  'calendar' => LucideIcons.calendarDays,
  'resource' => LucideIcons.chartNoAxesCombined,
  'task-map' => LucideIcons.mapPin,
  _ => LucideIcons.layoutDashboard,
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
    task['status']?.toString().toUpperCase() == 'DONE' ||
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

  List<Map<String, dynamic>> _tasks(dynamic raw) {
    final tasks = DashboardRepositoryImpl.items(raw);
    final options = widget.slot.options;
    if (widget.slot.id == 'resource' &&
        ['labels', 'epics'].contains(options['resourceFilterType'])) {
      final labels = (options['resourceLabelKeys'] as List? ?? [])
          .map((e) => e.toString())
          .toSet();
      final epics = (options['resourceEpicIds'] as List? ?? [])
          .map((e) => e.toString())
          .toSet();
      Set<String> taskLabels(Map<String, dynamic> task) =>
          (dashboardObject(task['detail'])['labels'] as List? ?? [])
              .whereType<Map>()
              .map(
                (e) => jsonEncode([
                  e['text']?.toString().toLowerCase() ?? '',
                  e['color']?.toString() ?? '',
                ]),
              )
              .toSet();
      Set<String> taskEpics(Map<String, dynamic> task) =>
          (task['epics'] as List? ?? [])
              .whereType<Map>()
              .map(
                (e) =>
                    (e['epicId'] ?? dashboardObject(e['epic'])['id'])
                        ?.toString() ??
                    '',
              )
              .toSet();
      if (options['resourceFilterType'] == 'labels') {
        final valid = labels.intersection(tasks.expand(taskLabels).toSet());
        return tasks
            .where(
              (e) =>
                  valid.isEmpty || taskLabels(e).intersection(valid).isNotEmpty,
            )
            .toList();
      }
      final valid = epics.intersection(tasks.expand(taskEpics).toSet());
      return tasks
          .where(
            (e) => valid.isEmpty || taskEpics(e).intersection(valid).isNotEmpty,
          )
          .toList();
    }
    final selected = widget.slot.id == 'team'
        ? options['teamProjectIds'] ??
              (options['teamProjectId'] != null &&
                      options['teamProjectId'] != 'all'
                  ? [options['teamProjectId']]
                  : [])
        : widget.slot.id == 'resource'
        ? (options['resourceProjectId'] != null &&
                  options['resourceProjectId'] != 'all'
              ? [options['resourceProjectId']]
              : [])
        : options['projectIds'] ??
              (options['projectId'] != null ? [options['projectId']] : []);
    final ids = (selected is List ? selected : [])
        .map((e) => e.toString())
        .toSet();
    if (ids.isNotEmpty) {
      for (final project in flattenDashboardProjects(widget.projects)) {
        if (ids.contains(project.id)) {
          ids.addAll(
            flattenDashboardProjects(project.children).map((e) => e.id),
          );
        }
      }
    }
    return tasks
        .where((e) => ids.isEmpty || ids.contains(e['projectId']))
        .toList();
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              onTap: () => context.go('/planner'),
            ),
          TextButton(
            onPressed: () => context.go('/planner'),
            child: const Text('Открыть ежедневник'),
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
            ..sort(
              (a, b) =>
                  (b.overdue >= 2 ? 1 : 0).compareTo(a.overdue >= 2 ? 1 : 0),
            );
      if (recommendations.isEmpty) return _empty('Нет рекомендаций');
      return _AiRecommendations(
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
      final selected = (widget.slot.options['projectIds'] as List? ?? [])
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
        initialProjectIds: (widget.slot.options['projectIds'] as List? ?? [])
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
        initialMode: widget.slot.options['mode']?.toString() ?? 'column',
        initialProjectIds: (widget.slot.options['projectIds'] as List? ?? [])
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
    final tasks = _tasks(data);
    if (kind == 'kpi-group') {
      return DashboardKpiWidget(
        key: ValueKey('${widget.workspaceId}:${widget.slot.instanceId}'),
        tasks: DashboardRepositoryImpl.items(data),
        projects: widget.projects,
        initialProjectIds: (widget.slot.options['projectIds'] as List? ?? [])
            .map((id) => id.toString())
            .toList(),
        trailing: widget.trailing,
        onOpenTask: _openTask,
      );
    }
    if (kind == 'task-map') {
      final located = tasks
          .where(
            (e) =>
                dashboardObject(
                  dashboardObject(e['detail'])['location'],
                )['address'] !=
                null,
          )
          .toList();
      final points = <(String, String, double, double)>[];
      for (final task in located) {
        final location = dashboardObject(
          dashboardObject(task['detail'])['location'],
        );
        final lat = location['latitude'], lng = location['longitude'];
        if (lat is num &&
            lng is num &&
            lat.isFinite &&
            lng.isFinite &&
            lat.abs() <= 90 &&
            lng.abs() <= 180) {
          points.add((
            task['id'].toString(),
            task['title']?.toString() ?? '',
            lat.toDouble(),
            lng.toDouble(),
          ));
        }
      }
      return Column(
        children: [
          DashboardTaskMap(tasks: points, onOpenTask: _openTask),
          if (located.isEmpty) _empty('У задач пока нет местоположений'),
          for (final task in located)
            Builder(
              builder: (context) {
                final location = dashboardObject(
                  dashboardObject(task['detail'])['location'],
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    LucideIcons.mapPin,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    task['title']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    location['address'].toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  onTap: () => _openTask(task['id'].toString()),
                  trailing: IconButton(
                    tooltip: 'Открыть на карте',
                    icon: const Icon(LucideIcons.externalLink, size: 16),
                    onPressed: () async {
                      try {
                        final latitude = location['latitude'],
                            longitude = location['longitude'];
                        final uri = Uri.https(
                          'yandex.ru',
                          '/maps/',
                          latitude is num && longitude is num
                              ? {
                                  'll': '$longitude,$latitude',
                                  'pt': '$longitude,$latitude,pm2rdm',
                                  'z': '16',
                                }
                              : {
                                  'text': location['address'].toString(),
                                  'mode': 'search',
                                },
                        );
                        await openStorageLink(uri.toString());
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            appSnackBar(
                              context: context,
                              tone: AppSnackBarTone.error,
                              content: Text('Не удалось открыть карту'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            ),
        ],
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
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: DashboardSurface.border),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.slot.id != 'team' &&
            widget.slot.id != 'kpi-group' &&
            widget.slot.id != 'tasks-summary' &&
            widget.slot.id != 'activity' &&
            widget.slot.id != 'resource' &&
            widget.slot.id != 'mentions')
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: AppWidgetHeading(
                    icon: dashboardWidgetIcon(widget.slot.id),
                    title: widget.slot.id == 'daily-motivation'
                        ? 'AI рекомендации'
                        : widget.slot.definition?.title ?? widget.slot.id,
                    iconColor: widget.slot.id == 'daily-motivation'
                        ? AppColors.accent
                        : AppColors.muted,
                  ),
                ),
                ?widget.trailing,
              ],
            ),
          ),
        if (widget.slot.id != 'daily-motivation' &&
            widget.slot.id != 'team' &&
            widget.slot.id != 'kpi-group' &&
            widget.slot.id != 'tasks-summary' &&
            widget.slot.id != 'activity' &&
            widget.slot.id != 'resource' &&
            widget.slot.id != 'mentions')
          const Divider(height: 1, color: AppColors.border),
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
                      const Text(
                        'Не удалось загрузить виджет',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
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
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return DashboardWidgetSkeleton(
                  kind: widget.slot.id,
                  showHeading: const [
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
                padding:
                    [
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
});

class _AiRecommendations extends StatelessWidget {
  const _AiRecommendations({required this.items});

  final List<_AiRecommendationData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _AiRecommendationCard(item: items[index]),
          if (index != items.length - 1)
            const Divider(height: AppSpacing.md, color: AppColors.border),
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
        ? '${item.count} ${_taskWord(item.count, short: true)}'
        : '${item.count} активных';
    final detail = item.isOverdue
        ? 'Пересмотрите сроки и приоритеты задач.'
        : 'Перераспределите задачи: средняя нагрузка — ${item.average}.';

    return Semantics(
      container: true,
      label: '${item.name}. $status. $detail',
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
                    item.name,
                    style: AppTypography.body(context)?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _StatusBadge(
                    label: status,
                    color: tone,
                    icon: item.isOverdue
                        ? LucideIcons.triangleAlert
                        : LucideIcons.gauge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    style: AppTypography.caption(
                      context,
                    )?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.md, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: AppTypography.caption(
                context,
              )?.copyWith(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
