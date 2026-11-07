import '../../../../core/widgets/app_widget_heading.dart';
import '../../../dashboard/presentation/widgets/dashboard_widget_skeleton.dart';
import '../../../dashboard/presentation/widgets/dashboard_expandable_content.dart';
import '../../../../core/theme/dashboard_surface.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../domain/entities/task_extra_field.dart';
import '../../domain/utils/my_tasks_utils.dart';
import '../cubit/my_tasks_cubit.dart';
import '../cubit/my_tasks_state.dart';

class MyTasksWidget extends StatelessWidget {
  const MyTasksWidget({
    super.key,
    this.height = 456,
    this.expandContent = false,
  });
  final double height;
  final bool expandContent;

  static const Color _ink = AppColors.ink;
  static const Color _muted = AppColors.muted;
  static const Color _border = AppColors.border;
  static const Color _error = AppColors.error;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MyTasksCubit, MyTasksState>(
      listenWhen: (previous, current) =>
          previous.actionRevision != current.actionRevision,
      listener: (context, state) {
        final message = state.actionErrorMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      builder: (context, state) {
        final projectMap = _flattenProjects(state.projects);
        final entries = DashboardPreviewScope.limit(
          context,
          _buildEntries(state, projectMap),
        );
        return Container(
          key: const Key('my-tasks-widget'),
          height: expandContent ? null : height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DashboardSurface.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Header(
                state: state,
                onProjectsTap: () => _showProjectFilter(context, state),
                onFieldsTap: () => _showFields(context),
                onSortTap: context.read<MyTasksCubit>().toggleSort,
              ),
              const Divider(height: 1, color: _border),
              if (expandContent)
                state.tasks.isEmpty
                    ? SizedBox(
                        height: 220,
                        child: _content(context, state, entries),
                      )
                    : _content(context, state, entries)
              else
                Expanded(child: _content(context, state, entries)),
            ],
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    MyTasksState state,
    List<_TaskListEntry> entries,
  ) {
    if (state.status == MyTasksStatus.loading && state.tasks.isEmpty) {
      return const _LoadingList();
    }
    if (state.status == MyTasksStatus.failure) {
      return _MessageList(
        icon: LucideIcons.circleAlert,
        message: state.errorMessage ?? 'Не удалось загрузить задачи',
        actionLabel: 'Повторить',
        onAction: context.read<MyTasksCubit>().refresh,
      );
    }
    if (state.tasks.isEmpty) {
      return _MessageList(
        icon: LucideIcons.circleCheckBig,
        message: 'Нет задач',
        onRefresh: context.read<MyTasksCubit>().refresh,
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: context.read<MyTasksCubit>().refresh,
      child: ListView.builder(
        key: const Key('my-tasks-list'),
        primary: false,
        shrinkWrap: expandContent,
        physics: expandContent
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return switch (entry) {
            _ProjectGroupEntry() => _ProjectGroupHeader(
              name: entry.projectName,
              count: entry.count,
            ),
            _TaskEntry() => _TaskRow(
              task: entry.task,
              columnName: state.columnName(entry.task),
              visibleFields: state.visibleFields,
              isUpdating: state.updatingTaskIds.contains(entry.task.id),
              onToggle: () =>
                  context.read<MyTasksCubit>().toggleTask(entry.task),
              onTap: () =>
                  context.push('/tasks/${entry.task.id}', extra: entry.task),
            ),
          };
        },
      ),
    );
  }

  List<_TaskListEntry> _buildEntries(
    MyTasksState state,
    Map<String, ProjectModel> projectMap,
  ) {
    final groups = <String, List<ProjectTaskModel>>{};
    for (final task in state.tasks) {
      groups.putIfAbsent(task.projectId, () => <ProjectTaskModel>[]).add(task);
    }
    final orderedIds = <String>[
      ...projectMap.keys.where(groups.containsKey),
      ...groups.keys.where((id) => !projectMap.containsKey(id)),
    ];
    final now = DateTime.now();
    return <_TaskListEntry>[
      for (final projectId in orderedIds) ...<_TaskListEntry>[
        _ProjectGroupEntry(
          projectName: projectMap[projectId]?.name ?? 'Проект',
          count: groups[projectId]!.length,
        ),
        ...sortTasksByDeadline(
          groups[projectId]!,
          ascending: state.sortAscending,
          now: now,
        ).map(_TaskEntry.new),
      ],
    ];
  }

  Map<String, ProjectModel> _flattenProjects(List<ProjectModel> projects) {
    final result = <String, ProjectModel>{};
    void visit(ProjectModel project) {
      result[project.id] = project;
      for (final child in project.children) {
        visit(child);
      }
    }

    for (final project in projects) {
      visit(project);
    }
    return result;
  }

  Future<void> _showProjectFilter(
    BuildContext context,
    MyTasksState state,
  ) async {
    var selected = Set<String>.from(state.selectedProjectIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Проекты',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, selected),
                          child: const Text('Готово'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        CheckboxListTile(
                          value: selected.isEmpty,
                          title: const Text('Все проекты'),
                          onChanged: (_) => setSheetState(selected.clear),
                        ),
                        for (final project in state.projects)
                          CheckboxListTile(
                            value: selected.contains(project.id),
                            title: Text(project.name),
                            onChanged: (_) => setSheetState(() {
                              selected.contains(project.id)
                                  ? selected.remove(project.id)
                                  : selected.add(project.id);
                            }),
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
    );
    if (result != null && context.mounted) {
      await context.read<MyTasksCubit>().selectProjects(result);
    }
  }

  Future<void> _showFields(BuildContext context) async {
    final cubit = context.read<MyTasksCubit>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => BlocProvider<MyTasksCubit>.value(
        value: cubit,
        child: SafeArea(
          child: BlocBuilder<MyTasksCubit, MyTasksState>(
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      'Показывать в списке',
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  for (final field in TaskExtraField.values)
                    CheckboxListTile(
                      value: state.visibleFields.contains(field),
                      title: Text(field.label),
                      onChanged: (_) =>
                          context.read<MyTasksCubit>().toggleField(field),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.onProjectsTap,
    required this.onFieldsTap,
    required this.onSortTap,
  });

  final MyTasksState state;
  final VoidCallback onProjectsTap;
  final VoidCallback onFieldsTap;
  final VoidCallback onSortTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: AppWidgetHeading(
                  icon: LucideIcons.userRoundCheck,
                  title: 'Мои задачи',
                ),
              ),
              TextButton(
                key: const Key('my-tasks-fields-button'),
                onPressed: onFieldsTap,
                style: TextButton.styleFrom(
                  foregroundColor: MyTasksWidget._muted,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Поля задачи'),
                    const SizedBox(width: 5),
                    _CountBadge(state.visibleFields.length),
                    const SizedBox(width: 2),
                    const Icon(
                      LucideIcons.chevronDown,
                      size: AppIconSizes.standard,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderAction(
                  key: const Key('my-tasks-project-filter'),
                  label: _projectFilterLabel(state),
                  icon: Icons.expand_more_rounded,
                  onTap: onProjectsTap,
                ),
              ),
              const SizedBox(width: 6),
              _HeaderAction(
                key: const Key('my-tasks-sort'),
                label: 'Срок',
                icon: state.sortAscending
                    ? Icons.north_rounded
                    : Icons.south_rounded,
                onTap: onSortTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _projectFilterLabel(MyTasksState state) {
    if (state.selectedProjectIds.isEmpty) return 'Все проекты';
    if (state.selectedProjectIds.length > 1) {
      return '${state.selectedProjectIds.length} проектов';
    }
    final id = state.selectedProjectIds.single;
    return state.projects
            .where((project) => project.id == id)
            .map((project) => project.name)
            .firstOrNull ??
        '1 проект';
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MyTasksWidget._muted,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              icon,
              size: AppIconSizes.standard,
              color: MyTasksWidget._muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.badgeSurface,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$count',
      style: GoogleFonts.manrope(fontSize: 9.5, color: MyTasksWidget._muted),
    ),
  );
}

sealed class _TaskListEntry {
  const _TaskListEntry();
}

class _ProjectGroupEntry extends _TaskListEntry {
  const _ProjectGroupEntry({required this.projectName, required this.count});

  final String projectName;
  final int count;
}

class _TaskEntry extends _TaskListEntry {
  const _TaskEntry(this.task);

  final ProjectTaskModel task;
}

class _ProjectGroupHeader extends StatelessWidget {
  const _ProjectGroupHeader({required this.name, required this.count});
  final String name;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      color: AppColors.subtleSurface,
      border: Border(bottom: BorderSide(color: MyTasksWidget._border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MyTasksWidget._muted,
            ),
          ),
        ),
        _CountBadge(count),
      ],
    ),
  );
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.columnName,
    required this.visibleFields,
    required this.isUpdating,
    required this.onToggle,
    required this.onTap,
  });
  final ProjectTaskModel task;
  final String columnName;
  final Set<TaskExtraField> visibleFields;
  final bool isUpdating;
  final VoidCallback onToggle, onTap;
  @override
  Widget build(BuildContext context) {
    final overdue = isTaskOverdue(task, DateTime.now());
    final epics = task.epicNames;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: MyTasksWidget._border)),
      ),
      child: InkWell(
        key: Key('my-task-${task.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 11, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  key: Key('my-task-checkbox-${task.id}'),
                  tooltip: task.isDone
                      ? 'Вернуть в работу'
                      : 'Завершить задачу',
                  padding: EdgeInsets.zero,
                  onPressed: isUpdating ? null : onToggle,
                  icon: _AnimatedTaskCheckbox(
                    checked: task.isDone,
                    isUpdating: isUpdating,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (visibleFields.contains(TaskExtraField.id))
                          Expanded(
                            child: Text(
                              task.displayId.isEmpty ? task.id : task.displayId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: MyTasksWidget._muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 6),
                        _DeadlineBadge(task: task, overdue: overdue),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.title.isEmpty ? 'Без названия' : task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: task.isDone
                            ? MyTasksWidget._muted
                            : MyTasksWidget._ink,
                      ),
                    ),
                    if ((visibleFields.contains(TaskExtraField.column) &&
                            columnName.trim().isNotEmpty &&
                            columnName != '—') ||
                        (visibleFields.contains(TaskExtraField.epics) &&
                            epics.isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          if (visibleFields.contains(TaskExtraField.column) &&
                              columnName.trim().isNotEmpty &&
                              columnName != '—')
                            _ColumnBadge(value: columnName),
                          if (visibleFields.contains(TaskExtraField.epics) &&
                              epics.isNotEmpty)
                            _EpicBadge(value: epics.join(', ')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedTaskCheckbox extends StatelessWidget {
  const _AnimatedTaskCheckbox({
    required this.checked,
    required this.isUpdating,
  });
  final bool checked, isUpdating;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 160),
    opacity: isUpdating ? .55 : 1,
    child: Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? AppColors.success : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: checked ? AppColors.success : MyTasksWidget._muted,
          width: 1.2,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: checked
            ? const Icon(
                Icons.check_rounded,
                key: ValueKey(true),
                size: 12,
                color: Colors.white,
              )
            : const SizedBox.shrink(key: ValueKey(false)),
      ),
    ),
  );
}

class _DeadlineBadge extends StatelessWidget {
  const _DeadlineBadge({required this.task, required this.overdue});
  final ProjectTaskModel task;
  final bool overdue;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: overdue
          ? MyTasksWidget._error.withValues(alpha: .07)
          : AppColors.subtleSurface,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.calendar,
          size: 12,
          color: overdue ? MyTasksWidget._error : MyTasksWidget._muted,
        ),
        const SizedBox(width: 4),
        Text(
          task.end == null ? 'Без срока' : formatRussianTaskDate(task.end!),
          style: GoogleFonts.manrope(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: overdue ? MyTasksWidget._error : MyTasksWidget._muted,
          ),
        ),
      ],
    ),
  );
}

class _EpicBadge extends StatelessWidget {
  const _EpicBadge({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 190),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.layers3, size: 12, color: AppColors.accent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ColumnBadge extends StatelessWidget {
  const _ColumnBadge({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 140),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.badgeSurface,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.columns3, size: 12, color: MyTasksWidget._muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: MyTasksWidget._muted,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const DashboardWidgetSkeleton(showHeading: false);
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onRefresh,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(
          height: 260,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: AppIconSizes.standard,
                color: MyTasksWidget._muted,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: MyTasksWidget._muted),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: () => onAction!(),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
