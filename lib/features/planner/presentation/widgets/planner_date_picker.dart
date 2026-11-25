import 'package:jospar/core/localization/app_translations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/utils/planner_dates.dart';

Future<DateTime?> showPlannerDatePicker({
  required BuildContext context,
  required DateTime initialDate,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => PlannerDatePickerDialog(initialDate: initialDate),
);

class PlannerDatePickerDialog extends StatefulWidget {
  const PlannerDatePickerDialog({super.key, required this.initialDate});
  final DateTime initialDate;
  @override
  State<PlannerDatePickerDialog> createState() =>
      _PlannerDatePickerDialogState();
}

class _PlannerDatePickerDialogState extends State<PlannerDatePickerDialog> {
  late final initial = DateTime.utc(
    widget.initialDate.year,
    widget.initialDate.month,
    widget.initialDate.day,
  );
  late DateTime selected = initial;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? FTheme.neutral.dark.touch : FTheme.neutral.light.touch;
    final theme = FThemeData(
      touch: true,
      colors: base.colors.copyWith(
        primary: AppColors.accent,
        primaryForeground: Colors.white,
      ),
    );
    final now = plannerNow();
    return Localizations.override(
      context: context,
      locale: Localizations.localeOf(context),
      delegates: FLocalizations.localizationsDelegates,
      child: FTheme(
        data: theme,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                    child: Text(
                      tr(context, 'Выберите дату'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => FCalendar.grid(
                      key: const Key('planner-date-calendar'),
                      headerBuilder: (context, controller, selection, child) {
                        if (controller.type != FCalendarPickerGridType.day) {
                          return child;
                        }
                        final date = controller.currentMonth;
                        final previous = controller.day.hasPrevious
                            ? controller.day.previous
                            : null;
                        final next = controller.day.hasNext
                            ? controller.day.next
                            : null;
                        const months = [
                          'Январь',
                          'Февраль',
                          'Март',
                          'Апрель',
                          'Май',
                          'Июнь',
                          'Июль',
                          'Август',
                          'Сентябрь',
                          'Октябрь',
                          'Ноябрь',
                          'Декабрь',
                        ];
                        final label = '${months[date.month - 1]} ${date.year}';
                        return Row(
                          children: [
                            Expanded(
                              child: FButton.raw(
                                key: const Key('planner-calendar-period'),
                                variant: FButtonVariant.ghost,
                                onPress: controller.cycle,
                                semanticsLabel: tr(
                                  context,
                                  "Выбрать месяц или год: {p0}",
                                  {'p0': label},
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        LucideIcons.chevronDown,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox.square(
                              dimension: 44,
                              child: FButton.icon(
                                key: const Key('planner-calendar-previous'),
                                variant: FButtonVariant.ghost,
                                onPress: previous,
                                semanticsLabel: tr(
                                  context,
                                  'Предыдущий период',
                                ),
                                child: const Icon(
                                  LucideIcons.chevronLeft,
                                  size: 18,
                                ),
                              ),
                            ),
                            SizedBox.square(
                              dimension: 44,
                              child: FButton.icon(
                                key: const Key('planner-calendar-next'),
                                variant: FButtonVariant.ghost,
                                onPress: next,
                                semanticsLabel: tr(context, 'Следующий период'),
                                child: const Icon(
                                  LucideIcons.chevronRight,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        );
                      },

                      fixedWeeks: true,
                      style: theme.calendarStyle.copyWith(
                        padding: const EdgeInsetsGeometryDelta.value(
                          EdgeInsets.zero,
                        ),
                        dayPickerStyle: theme.calendarStyle.dayPickerStyle
                            .copyWith(
                              daySize: Size(constraints.maxWidth / 7, 42),
                            ),
                      ),
                      control: FGridCalendarControl(
                        initial: initial,
                        today: DateTime.utc(now.year, now.month, now.day),
                        start: DateTime.utc(2020),
                        end: DateTime.utc(2100),
                      ),
                      selectionControl: FDateSelectionControl.managedSingle(
                        initial: initial,
                        toggleable: false,
                        onChange: (value) {
                          if (value != null) selected = value;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FButton(
                          variant: FButtonVariant.outline,
                          onPress: () => Navigator.pop(context),
                          child: Flexible(child: Text(tr(context, 'Отмена'))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FButton(
                          key: const Key('planner-date-done'),
                          onPress: () => Navigator.pop(
                            context,
                            DateTime(
                              selected.year,
                              selected.month,
                              selected.day,
                            ),
                          ),
                          child: Flexible(child: Text(tr(context, 'Готово'))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
