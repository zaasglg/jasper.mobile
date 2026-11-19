import '../../../../core/widgets/app_snack_bar.dart';
import 'board_style.dart';
import '../../../../core/theme/task_label_color.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/app_action_menu.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/card_view_settings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/domain/utils/my_tasks_utils.dart';
import '../../../planner/presentation/screens/planner_screen.dart';

Color _parseTagColor(String? value) => taskLabelColor(value ?? '');

enum TaskCardAction {
  cover('Обложка', LucideIcons.image),
  edit('Редактировать', LucideIcons.pencil),
  duplicate('Дублировать', LucideIcons.copy),
  move('Переместить', LucideIcons.arrowRight),
  schedule('В ежедневник', LucideIcons.calendarPlus),
  share('Поделиться', LucideIcons.share2),
  copyLink('Копировать ссылку', LucideIcons.link),
  translate('Перевести задачу', LucideIcons.languages),
  archive('Архивировать', LucideIcons.archive),
  delete('Удалить задачу', LucideIcons.trash2);

  const TaskCardAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onToggleCompleted,
    this.onMove,
    this.onAction,
    this.cardView = const CardViewSettings(),
    this.isUpdating = false,
    this.currentUserId,
    this.boardStyle = false,
  });

  final bool boardStyle;
  final String? currentUserId;
  final ProjectTaskModel task;
  final VoidCallback? onToggleCompleted;
  final VoidCallback? onMove;
  final ValueChanged<TaskCardAction>? onAction;
  final bool isUpdating;
  final CardViewSettings cardView;

  Future<void> _showActions(BuildContext context) async {
    final action = await showAppActionMenu<TaskCardAction>(
      context,
      title: task.title.isEmpty ? 'Без названия' : task.title,
      eyebrow: task.displayId.isEmpty ? 'Действия с задачей' : task.displayId,
      groups: [
        for (final group in const [
          [
            TaskCardAction.edit,
            TaskCardAction.move,
            TaskCardAction.duplicate,
            TaskCardAction.schedule,
          ],
          [TaskCardAction.cover, TaskCardAction.translate],
          [TaskCardAction.share, TaskCardAction.copyLink],
          [TaskCardAction.archive, TaskCardAction.delete],
        ])
          [
            for (final action in group)
              if (onAction != null ||
                  const {
                    TaskCardAction.edit,
                    TaskCardAction.schedule,
                    TaskCardAction.share,
                    TaskCardAction.copyLink,
                  }.contains(action))
                AppMenuAction(
                  value: action,
                  label: action.label,
                  icon: action.icon,
                  enabled: action != TaskCardAction.move || onMove != null,
                  destructive: action == TaskCardAction.delete,
                  muted: action == TaskCardAction.archive,
                  opensSubmenu: const {
                    TaskCardAction.cover,
                    TaskCardAction.move,
                    TaskCardAction.translate,
                  }.contains(action),
                ),
          ],
      ],
    );
    if (!context.mounted || action == null || isUpdating) return;
    switch (action) {
      case TaskCardAction.edit:
        context.push('/tasks/${task.id}', extra: task);
      case TaskCardAction.move:
        onMove?.call();
      case TaskCardAction.schedule:
        showScheduleProjectTask(context, task);
      case TaskCardAction.copyLink:
        await _shareTask(context, copy: true);
      case TaskCardAction.share:
        await _shareTask(context);
      default:
        onAction?.call(action);
    }
  }

  Future<void> _shareTask(BuildContext context, {bool copy = false}) async {
    final link = Uri.https('jospar.me', '/tasks', {
      'project': task.projectId,
      'taskId': task.id,
    }).toString();
    try {
      if (copy) {
        await Clipboard.setData(ClipboardData(text: link));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            appSnackBar(
              context: context,
              tone: AppSnackBarTone.success,
              content: Text('Ссылка скопирована'),
            ),
          );
        }
      } else {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            text:
                '${task.displayId.isEmpty ? '' : '${task.displayId}: '}${task.title}\n$link',
            subject: task.title,
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(
              copy
                  ? 'Не удалось скопировать ссылку.'
                  : 'Не удалось открыть меню отправки.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleEpics = cardView.shows(CardField.epics)
        ? task.epics.where((epic) => epic.name.trim().isNotEmpty).toList()
        : <TaskEpicModel>[];
    final visibleLabels = task
        .labelsForUser(currentUserId)
        .where(
          (label) =>
              label.text.trim().isNotEmpty &&
              cardView.shows(
                label.isPersonal ? CardField.personalLabels : CardField.labels,
              ),
        )
        .toList();
    final hasMetadata =
        (cardView.shows(CardField.dates) && task.end != null) ||
        (cardView.shows(CardField.checklists) && task.checklistTotal > 0) ||
        (cardView.shows(CardField.files) && task.fileCount > 0) ||
        (cardView.shows(CardField.comments) && task.commentCount > 0) ||
        (cardView.shows(CardField.timing) &&
            task.isTimingEnabled &&
            (task.estimate > 0 ||
                task.timerElapsedMs > 0 ||
                task.timerStartedAt != null)) ||
        (cardView.shows(CardField.resources) && task.resourceCount > 0) ||
        (cardView.shows(CardField.assignees) && task.assignees.isNotEmpty);
    final overdue = isTaskOverdue(task, DateTime.now());
    return InkWell(
      onTap: () => context.push('/tasks/${task.id}', extra: task),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? colors.surfaceContainerHigh
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: boardStyle
              ? null
              : Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
          boxShadow: boardStyle
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.06),
                    offset: const Offset(0, 1),
                    blurRadius: AppSpacing.xxs,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (cardView.shows(CardField.cover) && task.cover.isNotEmpty)
              TaskCover(cover: task.cover),
            if (boardStyle && cardView.shows(CardField.id))
              Text(
                task.displayId.isEmpty ? task.id : task.displayId,
                style: AppTypography.caption(
                  context,
                )?.copyWith(color: colors.onSurfaceVariant),
              ),
            if (!boardStyle)
              Row(
                children: <Widget>[
                  Expanded(
                    child: !cardView.shows(CardField.id)
                        ? const SizedBox.shrink()
                        : Text(
                            task.displayId.isEmpty ? task.id : task.displayId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.78,
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    key: ValueKey('task-actions-${task.id}'),
                    tooltip: 'Действия задачи',
                    onPressed: isUpdating ? null : () => _showActions(context),
                    icon: const Icon(
                      LucideIcons.ellipsis,
                      size: AppIconSizes.standard,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            if (!boardStyle) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TaskCompletionControl(
                  task: task,
                  isUpdating: isUpdating,
                  onPressed: onToggleCompleted,
                  compact: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    task.title.isEmpty ? 'Без названия' : task.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: boardStyle ? BoardStyle.cardTitleSize : 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (boardStyle)
                  IconButton(
                    key: ValueKey('task-actions-${task.id}'),
                    tooltip: 'Действия задачи',
                    onPressed: isUpdating ? null : () => _showActions(context),
                    icon: const Icon(
                      LucideIcons.ellipsis,
                      size: AppIconSizes.standard,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: AppSpacing.touchTarget,
                      height: AppSpacing.touchTarget,
                    ),
                  ),
              ],
            ),
            if (visibleEpics.isNotEmpty ||
                visibleLabels.isNotEmpty) ...<Widget>[
              const SizedBox(height: 9),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final epic in visibleEpics)
                    _TaskTag(
                      text: epic.name,
                      color: boardStyle
                          ? colors.onSurfaceVariant
                          : _parseTagColor(epic.color),
                      kind: 'Эпик',
                    ),
                  for (final label in visibleLabels)
                    _TaskTag(
                      text: label.text,
                      color: boardStyle
                          ? colors.onSurfaceVariant
                          : _parseTagColor(label.color),
                      kind: label.isPersonal ? 'Личная метка' : 'Метка',
                      outlined: label.isPersonal,
                      personal: label.isPersonal,
                    ),
                ],
              ),
            ],
            if (hasMetadata) ...[
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (cardView.shows(CardField.dates) && task.end != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.calendarDays,
                                size: AppIconSizes.standard,
                                color: overdue
                                    ? AppColors.error
                                    : AppColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatRussianTaskDate(task.end!),
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: overdue
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: overdue
                                      ? AppColors.error
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        if (cardView.shows(CardField.timing) &&
                            task.isTimingEnabled &&
                            (task.estimate > 0 ||
                                task.timerElapsedMs > 0 ||
                                task.timerStartedAt != null))
                          _TaskCardCount(
                            icon: LucideIcons.clock,
                            count: task.estimate > 0
                                ? '${task.estimate.toStringAsFixed(0)} мин'
                                : '${task.timerElapsedMs ~/ 60000} мин',
                            label: 'Тайминг задачи',
                          ),
                        if (cardView.shows(CardField.resources) &&
                            task.resourceCount > 0)
                          _TaskCardCount(
                            icon: LucideIcons.chartNoAxesCombined,
                            count: '${task.resourceCount}',
                            label: 'Ресурсы: ${task.resourceCount}',
                          ),
                        if (cardView.shows(CardField.checklists) &&
                            task.checklistTotal > 0)
                          _TaskCardCount(
                            icon: LucideIcons.listChecks,
                            count:
                                '${task.checklistCompleted}/${task.checklistTotal}',
                            label:
                                'Чек-лист: ${task.checklistCompleted} из ${task.checklistTotal}',
                          ),
                        if (cardView.shows(CardField.files) &&
                            task.fileCount > 0)
                          _TaskCardCount(
                            icon: LucideIcons.paperclip,
                            count: '${task.fileCount}',
                            label: 'Вложения: ${task.fileCount}',
                          ),
                        if (cardView.shows(CardField.comments) &&
                            task.commentCount > 0)
                          _TaskCardCount(
                            icon: LucideIcons.messageCircle,
                            count: '${task.commentCount}',
                            label: 'Обсуждения: ${task.commentCount}',
                          ),
                      ],
                    ),
                  ),
                  if (cardView.shows(CardField.assignees) &&
                      task.assignees.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _TaskAvatars(assignees: task.assignees),
                  ],
                ],
              ),
            ],
            if (cardView.shows(CardField.checklists) &&
                (task.progress ?? 0) > 0 &&
                (task.progress ?? 0) < 100) ...<Widget>[
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (task.progress ?? 0) / 100,
                  minHeight: 4,
                  backgroundColor: AppColors.skeletonTrack,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
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

class _TaskCompletionControl extends StatelessWidget {
  const _TaskCompletionControl({
    required this.task,
    required this.isUpdating,
    required this.onPressed,
    required this.compact,
  });
  final ProjectTaskModel task;
  final bool isUpdating;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      checked: task.isDone,
      label: task.isDone ? 'Вернуть задачу в работу' : 'Завершить задачу',
      child: IconButton(
        key: ValueKey('task-completion-${task.id}'),
        tooltip: task.isDone ? 'Вернуть в работу' : 'Завершить задачу',
        onPressed: isUpdating ? null : onPressed,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        style: IconButton.styleFrom(
          minimumSize: Size(
            compact ? 18 : AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
          maximumSize: Size(
            compact ? 18 : AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        constraints: BoxConstraints(
          minWidth: compact ? 18 : AppSpacing.touchTarget,
          minHeight: AppSpacing.touchTarget,
        ),
        visualDensity: VisualDensity.compact,
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: task.isDone ? AppColors.accent : Colors.transparent,
            border: Border.all(
              color: task.isDone ? AppColors.accent : colors.outline,
              width: 1.5,
            ),
          ),
          child: isUpdating
              ? Padding(
                  padding: const EdgeInsets.all(3),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: task.isDone ? Colors.white : AppColors.accent,
                  ),
                )
              : task.isDone
              ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _TaskCardCount extends StatelessWidget {
  const _TaskCardCount({
    required this.icon,
    required this.count,
    required this.label,
  });
  final IconData icon;
  final String count;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIconSizes.standard, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(
          count,
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _TaskTag extends StatelessWidget {
  const _TaskTag({
    required this.text,
    required this.color,
    required this.kind,
    this.outlined = false,
    this.personal = false,
  });
  final String text;
  final Color color;
  final String kind;
  final bool outlined;
  final bool personal;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Color.lerp(
      color,
      dark ? Colors.white : AppColors.ink,
      dark ? 0.35 : 0.22,
    )!;
    return Tooltip(
      message: '$kind: $text',
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: '$kind: $text',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(6),
            border: outlined
                ? Border.all(color: color.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (personal) ...[
                Icon(
                  LucideIcons.lockKeyhole,
                  size: AppIconSizes.standard,
                  color: foreground,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskAvatars extends StatelessWidget {
  const _TaskAvatars({required this.assignees});

  final List<TaskAssigneeModel> assignees;

  @override
  Widget build(BuildContext context) {
    final visible = assignees.take(3).toList(growable: false);
    return SizedBox(
      width: 28 + (visible.length - 1) * 19,
      height: 28,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 19,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1 + index * 0.04),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: UserAvatar(
                  size: 28,
                  userId: visible[index].userId,
                  name: visible[index].name,
                  avatarUrl: visible[index].avatarUrl,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                  foregroundColor: AppColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TaskCover extends StatelessWidget {
  const TaskCover({super.key, required this.cover});
  final Map<dynamic, dynamic> cover;

  @override
  Widget build(BuildContext context) {
    final color = cover['color'];
    final url = resolveUserAvatarUrl(
      (cover['url'] ?? cover['imageUrl'])?.toString(),
    );
    if (cover['type'] == 'color' && color is String) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: _parseTagColor(color),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    if (url == null) return const SizedBox.shrink();
    final Widget image;
    if (url.startsWith('data:image/')) {
      try {
        image = Image.memory(
          UriData.parse(url).contentAsBytes(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      } on FormatException {
        return const SizedBox.shrink();
      }
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(height: 120, width: double.infinity, child: image),
      ),
    );
  }
}
