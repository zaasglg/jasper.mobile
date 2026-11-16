import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/planner_item_model.dart';
import '../../domain/utils/planner_dates.dart';

/// A day is a sequence of tasks, not a fixed-height grid of empty hours.
class PlannerDayAgenda extends StatelessWidget {
  const PlannerDayAgenda({
    required this.selectedDate,
    required this.now,
    required this.items,
    required this.busyIds,
    required this.onCreate,
    required this.onEdit,
    required this.onToggle,
    super.key,
  });

  final DateTime selectedDate, now;
  final List<PlannerItemModel> items;
  final Set<String> busyIds;
  final VoidCallback onCreate;
  final ValueChanged<PlannerItemModel> onEdit, onToggle;

  @override
  Widget build(BuildContext context) {
    final sorted =
        items
            .where(
              (item) =>
                  !item.archived &&
                  !item.allDay &&
                  item.scheduledAt != null &&
                  samePlannerDay(plannerLocal(item.scheduledAt!), selectedDate),
            )
            .toList()
          ..sort((a, b) {
            final time = a.scheduledAt!.compareTo(b.scheduledAt!);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    if (sorted.isEmpty) {
      return _EmptyDayPlan(onCreate: onCreate);
    }

    final showNow = samePlannerDay(selectedDate, now);
    final nowIndex = showNow
        ? sorted.indexWhere((item) => item.scheduledAt!.isAfter(now))
        : -1;
    final markerIndex = nowIndex < 0 ? sorted.length : nowIndex;
    return ListView.builder(
      key: const Key('planner-day-agenda'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 96),
      itemCount: sorted.length + (showNow ? 1 : 0),
      itemBuilder: (context, index) {
        if (showNow && index == markerIndex) {
          return Padding(
            key: const Key('planner-now-marker'),
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 20),
            child: Row(
              children: [
                Text(
                  plannerClock(now),
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.circle, size: 7, color: AppColors.accent),
                const SizedBox(width: 8),
                const Expanded(child: Divider(color: AppColors.accent)),
                const SizedBox(width: 8),
                Text(
                  'Сейчас',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          );
        }
        final taskIndex = showNow && index > markerIndex ? index - 1 : index;
        final item = sorted[taskIndex];
        return _AgendaTask(
          key: ValueKey('planner-agenda-${item.id}'),
          item: item,
          first: taskIndex == 0,
          last: taskIndex == sorted.length - 1,
          busy: busyIds.contains(item.id),
          onEdit: () => onEdit(item),
          onToggle: () => onToggle(item),
        );
      },
    );
  }
}

class _EmptyDayPlan extends StatelessWidget {
  const _EmptyDayPlan({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 360;
        return CustomScrollView(
          key: const Key('planner-day-agenda'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!compact) ...[
                            const _EmptyPlanIllustration(),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            'Ваш день. Ваш план.',
                            key: const Key('planner-empty-title'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: compact ? 24 : 26,
                              height: 1.2,
                              letterSpacing: -0.7,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Начните с одного дела.\nРешайте сами, чем наполнить этот день.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              height: 1.6,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            key: const Key('planner-empty-create'),
                            onPressed: onCreate,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: const Text(
                              'Добавить первое дело',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 28),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.subtleSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    LucideIcons.hand,
                                    size: 18,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                'Можно взять задачу из проекта\n',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colors.onSurface,
                                            ),
                                          ),
                                          const TextSpan(
                                            text:
                                                'Зажмите карточку и перетащите на блок «В ежедневник».',
                                          ),
                                        ],
                                      ),
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        height: 1.6,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyPlanIllustration extends StatelessWidget {
  const _EmptyPlanIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: 132,
        height: 104,
        child: Stack(
          children: [
            Positioned(
              left: 17,
              top: 7,
              width: 90,
              height: 88,
              child: Transform.rotate(
                angle: -0.1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.subtleSurface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 27,
              top: 0,
              width: 90,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.notebookPen,
                        size: 22,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 12),
                      Container(height: 3, color: AppColors.border),
                      const SizedBox(height: 8),
                      Container(width: 38, height: 3, color: AppColors.border),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 3,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    LucideIcons.plus,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaTask extends StatelessWidget {
  const _AgendaTask({
    required this.item,
    required this.first,
    required this.last,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    super.key,
  });

  final PlannerItemModel item;
  final bool first, last, busy;
  final VoidCallback onEdit, onToggle;

  @override
  Widget build(BuildContext context) {
    final color = item.external
        ? const Color(0xFF6886A5)
        : item.inboxTaskId != null
        ? const Color(0xFFC78372)
        : item.taskId != null
        ? const Color(0xFF549488)
        : AppColors.accent;
    final source = item.external
        ? 'Google Календарь'
        : item.inboxTaskId != null
        ? 'Инбокс'
        : item.taskId != null
        ? item.projectName
        : 'Личное';
    return Stack(
      children: [
        Positioned(
          left: 73,
          top: first ? 34 : 0,
          bottom: last ? null : 0,
          height: last ? (first ? 0 : 34) : null,
          width: 2,
          child: const ColoredBox(color: AppColors.border),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Text(
                    plannerClock(plannerLocal(item.scheduledAt!)),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 12, 0),
                child: SizedBox.square(
                  dimension: 44,
                  child: IconButton.filled(
                    key: ValueKey(
                      item.external
                          ? 'planner-event-${item.id}'
                          : 'planner-complete-${item.id}',
                    ),
                    tooltip: item.external
                        ? 'Событие Google Календаря'
                        : item.completed
                        ? 'Вернуть в план'
                        : 'Отметить выполненной',
                    onPressed: busy
                        ? null
                        : item.external
                        ? onEdit
                        : onToggle,
                    style: IconButton.styleFrom(
                      backgroundColor: color.withValues(
                        alpha: item.completed ? 0.12 : 1,
                      ),
                      foregroundColor: item.completed ? color : Colors.white,
                      disabledBackgroundColor: color.withValues(alpha: 0.12),
                    ),
                    icon: busy
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(
                            item.completed
                                ? Icons.check_rounded
                                : item.external
                                ? Icons.event_outlined
                                : item.inboxTaskId != null
                                ? Icons.inbox_outlined
                                : item.taskId != null
                                ? Icons.work_outline_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 21,
                          ),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: item.completed
                      ? Colors.transparent
                      : color.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: ValueKey('planner-open-${item.id}'),
                    onTap: busy ? null : onEdit,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayTitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: item.completed
                                  ? AppColors.muted
                                  : AppColors.ink,
                              decoration: item.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.completed ? '$source · Выполнено' : source,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
