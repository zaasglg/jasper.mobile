import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/utils/planner_dates.dart';

class PlannerDayWeekStrip extends StatelessWidget {
  const PlannerDayWeekStrip({
    super.key,
    required this.selectedDate,
    required this.onSelected,
    this.now,
  });
  final DateTime selectedDate;
  final DateTime? now;
  final ValueChanged<DateTime> onSelected;
  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final today = plannerDate(now ?? plannerNow());
    final monday = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - selectedDate.weekday + 1,
    );
    return Container(
      key: const Key('planner-day-week-strip'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: .5)),
      ),
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
          final width = math.max(constraints.maxWidth / 7, 44 * scale);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Builder(
                    builder: (context) {
                      final day = DateTime(
                        monday.year,
                        monday.month,
                        monday.day + i,
                      );
                      final selected = samePlannerDay(day, selectedDate);
                      final isToday = samePlannerDay(day, today);
                      return SizedBox(
                        width: width,
                        child: Semantics(
                          selected: selected,
                          button: true,
                          label:
                              '${tr(context, _weekdays[i])}, ${day.day}.${day.month}.${day.year}${isToday ? ', ${tr(context, 'Сегодня')}' : ''}',
                          excludeSemantics: true,
                          child: Material(
                            color: selected
                                ? colors.accent.withValues(alpha: .09)
                                : Colors.transparent,
                            child: InkWell(
                              key: ValueKey(
                                'planner-day-${plannerDayString(day)}',
                              ),
                              onTap: () => onSelected(day),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 8,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${tr(context, _weekdays[i])},',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: selected
                                                ? colors.ink
                                                : colors.muted,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Container(
                                          key: isToday
                                              ? ValueKey(
                                                  'planner-today-${plannerDayString(day)}',
                                                )
                                              : null,
                                          width: 27 * scale,
                                          height: 27 * scale,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isToday
                                                ? const Color(0xFF6C3BFF)
                                                : Colors.transparent,
                                          ),
                                          child: Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isToday
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: isToday
                                                  ? Colors.white
                                                  : i >= 5 && !selected
                                                  ? colors.muted
                                                  : colors.ink,
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
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
