import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/domain/utils/my_tasks_utils.dart';

Color _parseTagColor(String? value) {
  final source = value?.trim();
  if (source == null || source.isEmpty) return AppColors.accent;

  var hex = source.startsWith('#') ? source.substring(1) : source;
  if (hex.length == 3) {
    hex = hex.split('').map((character) => '$character$character').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return AppColors.accent;

  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? AppColors.accent : Color(parsed);
}

enum _TaskMenuAction {
  cover('Обложка', LucideIcons.image),
  edit('Редактировать', LucideIcons.pencil),
  duplicate('Дублировать', LucideIcons.copy),
  move('Переместить', LucideIcons.arrowRight),
  share('Поделиться', LucideIcons.share2),
  copyLink('Копировать ссылку', LucideIcons.link),
  translate('Перевести задачу', LucideIcons.languages),
  archive('Архивировать', LucideIcons.archive),
  delete('Удалить задачу', LucideIcons.trash2);

  const _TaskMenuAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});

  final ProjectTaskModel task;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overdue = isTaskOverdue(task, DateTime.now());
    return InkWell(
      onTap: () => context.push('/tasks/${task.id}', extra: task),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? colors.surfaceContainerHigh
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.045),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    task.displayId.isEmpty ? task.id : task.displayId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 28,
                  child: PopupMenuButton<_TaskMenuAction>(
                    key: ValueKey('task-actions-${task.id}'),
                    tooltip: 'Действия задачи',
                    onSelected: (action) {
                      if (action == _TaskMenuAction.edit) {
                        context.push('/tasks/${task.id}', extra: task);
                      }
                    },
                    padding: EdgeInsets.zero,
                    icon: const Icon(LucideIcons.ellipsis, size: 17),
                    position: PopupMenuPosition.under,
                    color: colors.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 8,
                    shadowColor: AppColors.ink.withValues(alpha: 0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 248,
                      maxWidth: 300,
                    ),
                    itemBuilder: (context) => [
                      for (final action in _TaskMenuAction.values) ...[
                        if (action == _TaskMenuAction.archive ||
                            action == _TaskMenuAction.delete)
                          const PopupMenuDivider(height: 9),
                        PopupMenuItem<_TaskMenuAction>(
                          value: action,
                          height: 45,
                          child: Row(
                            children: [
                              Icon(
                                action.icon,
                                size: 19,
                                color: action == _TaskMenuAction.delete
                                    ? AppColors.error
                                    : action == _TaskMenuAction.archive
                                    ? AppColors.muted
                                    : AppColors.accent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  action.label,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: action == _TaskMenuAction.delete
                                        ? AppColors.error
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                              if (action == _TaskMenuAction.translate)
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 17,
                                  color: colors.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.title.isEmpty ? 'Без названия' : task.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            if (task.epicNames.isNotEmpty ||
                task.labels.isNotEmpty) ...<Widget>[
              const SizedBox(height: 9),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final epic in task.epics.where(
                    (epic) => epic.name.trim().isNotEmpty,
                  ))
                    _TaskTag(
                      text: epic.name,
                      color: _parseTagColor(epic.color),
                      kind: 'Эпик',
                    ),
                  for (final label in task.labels.where(
                    (label) => label.text.trim().isNotEmpty,
                  ))
                    _TaskTag(
                      text: label.text,
                      color: _parseTagColor(label.color),
                      kind: label.isPersonal ? 'Личная метка' : 'Метка',
                      outlined: label.isPersonal,
                      personal: label.isPersonal,
                    ),
                ],
              ),
            ],
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
                      if (task.end != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.calendarDays,
                              size: 16,
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
                      if (task.checklistTotal > 0)
                        _TaskCardCount(
                          icon: LucideIcons.listChecks,
                          count:
                              '${task.checklistCompleted}/${task.checklistTotal}',
                          label:
                              'Чек-лист: ${task.checklistCompleted} из ${task.checklistTotal}',
                        ),
                      if (task.fileCount > 0)
                        _TaskCardCount(
                          icon: LucideIcons.paperclip,
                          count: '${task.fileCount}',
                          label: 'Вложения: ${task.fileCount}',
                        ),
                      if (task.commentCount > 0)
                        _TaskCardCount(
                          icon: LucideIcons.messageCircle,
                          count: '${task.commentCount}',
                          label: 'Обсуждения: ${task.commentCount}',
                        ),
                    ],
                  ),
                ),
                if (task.assignees.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _TaskAvatars(assignees: task.assignees),
                ],
              ],
            ),
            if ((task.progress ?? 0) > 0 &&
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
        Icon(icon, size: 16, color: AppColors.muted),
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
                Icon(LucideIcons.lockKeyhole, size: 10, color: foreground),
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
