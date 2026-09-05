import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/kanban_column_model.dart';
import '../../data/models/task_detail_model.dart';
import '../../domain/utils/my_tasks_utils.dart';
import '../cubit/task_details_cubit.dart';
import '../cubit/task_details_state.dart';

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({super.key, required this.taskId, this.task});

  final String taskId;
  final ProjectTaskModel? task;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _showHistory = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskDetailsCubit, TaskDetailsState>(
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
        final task = state.task ?? widget.task;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 0,
            title: Text(
              task?.displayId.trim().isNotEmpty == true
                  ? task!.displayId
                  : 'Задача',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Обновить',
                onPressed: context.read<TaskDetailsCubit>().refresh,
                icon: const Icon(LucideIcons.refreshCw, size: 19),
              ),
            ],
          ),
          body: _body(context, state, task),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    TaskDetailsState state,
    ProjectTaskModel? task,
  ) {
    if (state.status == TaskDetailsStatus.initial ||
        state.status == TaskDetailsStatus.loading) {
      return const _DetailsLoadingView();
    }
    if (task == null) {
      return _DetailsError(
        message: state.errorMessage ?? 'Задача не найдена.',
        onRetry: () => context.read<TaskDetailsCubit>().load(widget.taskId),
      );
    }

    return Stack(
      children: <Widget>[
        RefreshIndicator.adaptive(
          onRefresh: context.read<TaskDetailsCubit>().refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: <Widget>[
              if (state.status == TaskDetailsStatus.failure)
                _InlineError(message: state.errorMessage ?? 'Ошибка загрузки'),
              _TaskHeader(
                task: task,
                labels: state.detail.labels,
                columnName: _columnName(task.status, state.columns),
                onToggleCompleted: context
                    .read<TaskDetailsCubit>()
                    .toggleCompleted,
              ),
              const SizedBox(height: 20),
              _Description(
                value: state.detail.description,
                onTap: () => _editDescription(state.detail.description),
              ),
              const SizedBox(height: 14),
              _MetadataStrip(
                task: task,
                detail: state.detail,
                onDeadlineTap: () => _selectDeadline(task.end),
              ),
              const SizedBox(height: 18),
              _ExpandableSection(
                icon: LucideIcons.chartNoAxesCombined,
                title: 'Ресурс',
                count: state.resources.length,
                initiallyExpanded: state.resources.isNotEmpty,
                child: _Resources(resources: state.resources),
              ),
              _ExpandableSection(
                icon: LucideIcons.listChecks,
                title: 'Чек-листы',
                count: state.detail.checklistTotal,
                progress: state.detail.checklistProgress,
                initiallyExpanded: state.detail.checklists.isNotEmpty,
                child: _Checklists(
                  checklists: state.detail.checklists,
                  enabled: !state.isSaving,
                  onToggle: context
                      .read<TaskDetailsCubit>()
                      .toggleChecklistItem,
                ),
              ),
              _ExpandableSection(
                icon: LucideIcons.messageSquare,
                title: 'Обсуждение',
                count: state.detail.comments.length,
                initiallyExpanded: state.detail.comments.isNotEmpty,
                child: _Discussion(
                  comments: state.detail.comments,
                  controller: _commentController,
                  isSending: state.isSaving,
                  onSend: _sendComment,
                ),
              ),
              const SizedBox(height: 10),
              _DetailTabs(
                historySelected: _showHistory,
                fileCount: state.detail.files.length,
                historyCount: state.history.length,
                onChanged: (value) => setState(() => _showHistory = value),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _showHistory
                    ? _History(
                        key: const ValueKey<String>('history'),
                        entries: state.history,
                      )
                    : _Files(
                        key: const ValueKey<String>('files'),
                        files: state.detail.files,
                      ),
              ),
            ],
          ),
        ),
        if (state.isSaving)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _editDescription(String value) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DescriptionEditor(initialValue: value),
    );
    if (result != null && mounted) {
      await context.read<TaskDetailsCubit>().updateDescription(result);
    }
  }

  Future<void> _selectDeadline(DateTime? current) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current?.toLocal() ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Выберите срок',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (selected != null && mounted) {
      await context.read<TaskDetailsCubit>().updateDeadline(selected);
    }
  }

  Future<void> _sendComment() async {
    final value = _commentController.text.trim();
    if (value.isEmpty) return;
    final cubit = context.read<TaskDetailsCubit>();
    final previousCount = cubit.state.detail.comments.length;
    await cubit.addComment(value);
    if (mounted && cubit.state.detail.comments.length > previousCount) {
      _commentController.clear();
    }
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({
    required this.task,
    required this.labels,
    required this.columnName,
    required this.onToggleCompleted,
  });

  final ProjectTaskModel task;
  final List<TaskLabelModel> labels;
  final String columnName;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            _SoftChip(icon: LucideIcons.columns3, label: columnName),
            for (final epic in task.epicNames)
              _SoftChip(icon: LucideIcons.layers3, label: epic),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: onToggleCompleted,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: task.isDone ? AppColors.success : Colors.transparent,
                  shape: BoxShape.circle,
                  border: task.isDone
                      ? null
                      : Border.all(color: colors.outlineVariant, width: 2),
                ),
                child: task.isDone
                    ? const Icon(
                        LucideIcons.check,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title.trim().isEmpty ? 'Без названия' : task.title,
                style: GoogleFonts.manrope(
                  fontSize: 25,
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (labels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: labels
                .map((label) => _LabelChip(label: label))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmpty = value.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(LucideIcons.alignLeft, size: 18, color: AppColors.ink),
            const SizedBox(width: 9),
            Text(
              'Описание',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: const Color(0xFFF5F5F4),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 11, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      isEmpty ? 'Добавить описание…' : value,
                      maxLines: isEmpty ? 1 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        height: 1.45,
                        color: isEmpty ? AppColors.muted : colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.pencil,
                    size: 16,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataStrip extends StatelessWidget {
  const _MetadataStrip({
    required this.task,
    required this.detail,
    required this.onDeadlineTap,
  });

  final ProjectTaskModel task;
  final TaskDetailModel detail;
  final VoidCallback onDeadlineTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetadataCard(
              width: itemWidth,
              label: 'Исполнители',
              icon: LucideIcons.users,
              child: task.assignees.isEmpty
                  ? const Text('Не назначены')
                  : _Assignees(assignees: task.assignees),
            ),
            _MetadataCard(
              width: itemWidth,
              label: 'Срок',
              icon: LucideIcons.calendarClock,
              onTap: onDeadlineTap,
              child: Text(
                task.end == null
                    ? 'Без срока'
                    : formatRussianTaskDate(task.end!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isTaskOverdue(task, DateTime.now())
                      ? AppColors.error
                      : null,
                ),
              ),
            ),
            _MetadataCard(
              width: itemWidth,
              label: 'Тайминг',
              icon: LucideIcons.timer,
              child: Text(
                _timing(detail.estimateMinutes),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _MetadataCard(
              width: itemWidth,
              label: 'Прогресс',
              icon: LucideIcons.gauge,
              child: Text(
                '${(task.progress ?? 0).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({
    required this.width,
    required this.label,
    required this.icon,
    required this.child,
    this.onTap,
  });

  final double width;
  final String label;
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 76,
      child: Material(
        color: const Color(0xFFF5F5F4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(icon, size: 15, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    if (onTap != null) ...<Widget>[
                      const Spacer(),
                      const Icon(
                        LucideIcons.pencil,
                        size: 13,
                        color: AppColors.muted,
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                DefaultTextStyle(
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.onSurface,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  const _ExpandableSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.child,
    this.progress,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final int count;
  final double? progress;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(widget.icon, size: 19, color: AppColors.ink),
                    const SizedBox(width: 10),
                    Text(
                      widget.title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (widget.count > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      _CountBadge(count: widget.count),
                    ],
                    const Spacer(),
                    if (widget.progress != null)
                      Text(
                        '${(widget.progress! * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: const Icon(
                        LucideIcons.chevronDown,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                if (widget.progress != null) ...<Widget>[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 4,
                      backgroundColor: AppColors.skeletonTrack,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: widget.child,
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOutCubic,
        ),
        Divider(
          height: 1,
          color: colors.outlineVariant.withValues(alpha: 0.38),
        ),
      ],
    );
  }
}

class _Resources extends StatelessWidget {
  const _Resources({required this.resources});

  final List<TaskResourceModel> resources;

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) return const _EmptyText('Нет ресурсов.');
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: resources
              .map(
                (resource) => SizedBox(
                  width: itemWidth,
                  child: _ResourceRow(resource: resource),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.resource});

  final TaskResourceModel resource;

  @override
  Widget build(BuildContext context) {
    final ratio = resource.ratio;
    return Container(
      height: 132,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  resource.name.isEmpty ? 'Ресурс' : resource.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: 'План',
                  value: _number(resource.planValue),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Факт',
                  value: _number(resource.factValue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 5,
              backgroundColor: AppColors.skeletonTrack,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Checklists extends StatelessWidget {
  const _Checklists({
    required this.checklists,
    required this.enabled,
    required this.onToggle,
  });

  final List<TaskChecklistModel> checklists;
  final bool enabled;
  final void Function(String checklistId, String itemId) onToggle;

  @override
  Widget build(BuildContext context) {
    if (checklists.isEmpty) return const _EmptyText('Нет чек-листов.');
    return Column(
      children: checklists
          .map(
            (checklist) => _ChecklistCard(
              checklist: checklist,
              enabled: enabled,
              onToggle: (itemId) => onToggle(checklist.id, itemId),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.checklist,
    required this.enabled,
    required this.onToggle,
  });

  final TaskChecklistModel checklist;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                LucideIcons.squareCheckBig,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  checklist.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${checklist.completed}/${checklist.total}'),
            ],
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: checklist.progress,
            minHeight: 4,
            backgroundColor: AppColors.skeletonTrack,
          ),
          const SizedBox(height: 7),
          for (final item in checklist.items)
            _ChecklistItem(
              item: item,
              enabled: enabled,
              onChanged: () => onToggle(item.id),
            ),
          for (final section in checklist.sections) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Text(
                section.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ),
            for (final item in section.items)
              _ChecklistItem(
                item: item,
                enabled: enabled,
                onChanged: () => onToggle(item.id),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.item,
    required this.enabled,
    required this.onChanged,
  });

  final TaskChecklistItemModel item;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onChanged : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: <Widget>[
            Checkbox.adaptive(
              value: item.done,
              onChanged: enabled ? (_) => onChanged() : null,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                item.text,
                style: TextStyle(
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  color: item.done ? AppColors.muted : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Discussion extends StatelessWidget {
  const _Discussion({
    required this.comments,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final List<TaskCommentModel> comments;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _EmptyText('Комментариев пока нет.'),
          )
        else
          for (final comment in comments) _CommentBubble(comment: comment),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 7, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Написать комментарий…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Отправить',
                onPressed: isSending ? null : onSend,
                icon: const Icon(LucideIcons.send, size: 17),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});

  final TaskCommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.success.withValues(alpha: 0.14),
            foregroundColor: AppColors.success,
            child: Text(
              _initial(comment.author),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        comment.author,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _commentTime(comment.time),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(comment.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.historySelected,
    required this.fileCount,
    required this.historyCount,
    required this.onChanged,
  });

  final bool historySelected;
  final int fileCount;
  final int historyCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _TabButton(
          selected: !historySelected,
          icon: LucideIcons.paperclip,
          label: 'Файлы',
          count: fileCount,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 4),
        _TabButton(
          selected: historySelected,
          icon: LucideIcons.history,
          label: 'История',
          count: historyCount,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 17,
              color: selected ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.accent : AppColors.muted,
              ),
            ),
            if (count > 0) ...<Widget>[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.accent : AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Files extends StatelessWidget {
  const _Files({super.key, required this.files});

  final List<TaskFileModel> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const _EmptyText('Нет прикреплённых файлов.');
    return Column(
      children: files
          .map(
            (file) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.file,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_fileSize(file.size)),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _History extends StatelessWidget {
  const _History({super.key, required this.entries});

  final List<TaskHistoryEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _EmptyText('Нет записей истории.');
    return Column(
      children: entries
          .map((entry) => _HistoryRow(entry: entry))
          .toList(growable: false),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final TaskHistoryEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.zap,
              size: 16,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '${entry.actorName ?? 'Пользователь'} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: _historyLabel(entry)),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _dateTime(entry.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.085),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});

  final TaskLabelModel label;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(label.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Assignees extends StatelessWidget {
  const _Assignees({required this.assignees});

  final List<TaskAssigneeModel> assignees;

  @override
  Widget build(BuildContext context) {
    final visible = assignees.take(3).toList(growable: false);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 28 + (visible.length - 1) * 20,
          height: 28,
          child: Stack(
            children: <Widget>[
              for (var index = 0; index < visible.length; index++)
                Positioned(
                  left: index * 20,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.accent.withValues(
                      alpha: 0.1 + index * 0.04,
                    ),
                    foregroundColor: AppColors.accent,
                    child: Text(
                      _initial(visible[index].name),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            assignees.first.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _DescriptionEditor extends StatefulWidget {
  const _DescriptionEditor({required this.initialValue});

  final String initialValue;

  @override
  State<_DescriptionEditor> createState() => _DescriptionEditorState();
}

class _DescriptionEditorState extends State<_DescriptionEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Описание',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(hintText: 'Добавьте описание…'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, _controller.text),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsLoadingView extends StatefulWidget {
  const _DetailsLoadingView();

  @override
  State<_DetailsLoadingView> createState() => _DetailsLoadingViewState();
}

class _DetailsLoadingViewState extends State<_DetailsLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) => AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final opacity = 0.45 + (_controller.value - 0.5).abs() * 0.45;
              return Opacity(opacity: opacity, child: child);
            },
            child: Container(
              height: index == 0 ? 110 : 72,
              decoration: BoxDecoration(
                color: AppColors.skeleton,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2.4),
                ),
                SizedBox(width: 12),
                Text('Загрузка задачи…'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(LucideIcons.circleAlert, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status.toUpperCase()) {
    'BACKLOG' => 'Очередь',
    'TODO' => 'К работе',
    'PROGRESS' => 'В работе',
    'REVIEW' => 'На проверке',
    'DONE' => 'Готово',
    _ => status.isEmpty ? 'Без статуса' : status,
  };
}

String _columnName(String status, List<KanbanColumnModel> columns) {
  for (final column in columns) {
    if (column.statusMap.toString().toUpperCase() == status.toUpperCase()) {
      final name = column.name.toString().trim();
      if (name.isNotEmpty) return name;
    }
  }
  return _statusLabel(status);
}

String _historyLabel(TaskHistoryEntryModel entry) {
  final change = entry.fromValue != null || entry.toValue != null
      ? ' (${entry.fromValue ?? '—'} → ${entry.toValue ?? '—'})'
      : '';
  return switch (entry.type) {
    'title_changed' => 'изменил(а) название$change',
    'priority_changed' => 'изменил(а) приоритет$change',
    'date_changed' => 'изменил(а) срок',
    'task_completed' => 'завершил(а) задачу',
    'task_reopened' => 'вернул(а) задачу в работу',
    'progress_changed' => 'изменил(а) прогресс$change',
    'description_changed' => 'изменил(а) описание',
    'label_added' => 'добавил(а) метку ${entry.subjectName ?? ''}',
    'label_removed' => 'удалил(а) метку ${entry.subjectName ?? ''}',
    'assignee_added' => 'добавил(а) исполнителя ${entry.subjectName ?? ''}',
    'assignee_removed' => 'удалил(а) исполнителя ${entry.subjectName ?? ''}',
    'epic_added' => 'добавил(а) эпик ${entry.subjectName ?? ''}',
    'epic_removed' => 'удалил(а) эпик ${entry.subjectName ?? ''}',
    'task_created' => 'создал(а) задачу',
    _ => 'обновил(а) задачу',
  };
}

String _commentTime(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : _dateTime(parsed);
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final hours = local.hour.toString().padLeft(2, '0');
  final minutes = local.minute.toString().padLeft(2, '0');
  return '${formatRussianTaskDate(local)}, $hours:$minutes';
}

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

String _number(double value) {
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
}

String _timing(int? minutes) {
  if (minutes == null || minutes <= 0) return 'Не задан';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest мин';
  if (rest == 0) return '$hours ч';
  return '$hours ч $rest мин';
}

String _initial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '•' : trimmed.characters.first.toUpperCase();
}

Color _parseColor(String value) {
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((character) => '$character$character').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = hex.length == 8 ? int.tryParse(hex, radix: 16) : null;
  return parsed == null ? AppColors.accent : Color(parsed);
}
