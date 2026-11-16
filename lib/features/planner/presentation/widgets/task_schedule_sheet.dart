import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/utils/planner_dates.dart';
import '../cubit/planner_cubit.dart';
import '../cubit/planner_state.dart';

enum TaskScheduleResult { added, rescheduled }

class TaskScheduleSheet extends StatefulWidget {
  const TaskScheduleSheet({
    required this.title,
    required this.source,
    this.projectId,
    this.taskId,
    this.inboxTaskId,
    super.key,
  });
  final String title, source;
  final String? projectId, taskId, inboxTaskId;

  @override
  State<TaskScheduleSheet> createState() => _TaskScheduleSheetState();
}

class _TaskScheduleSheetState extends State<TaskScheduleSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  int _duration = 30;
  bool _prepared = false, _existing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = plannerNow();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 30 + 1) * 30,
    );
    _date = plannerDate(next);
    _time = TimeOfDay.fromDateTime(next);
  }

  void _prepare(PlannerState state) {
    if (_prepared || state.status != PlannerStatus.success) return;
    final item = state.items
        .where(
          (item) =>
              (widget.taskId != null && item.taskId == widget.taskId) ||
              (widget.inboxTaskId != null &&
                  item.inboxTaskId == widget.inboxTaskId),
        )
        .firstOrNull;
    _existing = item != null;
    if (item != null) {
      final scheduled = item.scheduledAt;
      if (scheduled != null) {
        final local = plannerLocal(scheduled);
        _date = plannerDate(local);
        _time = TimeOfDay.fromDateTime(local);
      }
      _duration = item.durationMinutes.clamp(15, 1440);
    }
    _prepared = true;
  }

  Future<void> _save() async {
    final cubit = context.read<PlannerCubit>();
    if (!_prepared || cubit.state.isSaving) return;
    setState(() => _error = null);
    final success = await cubit.addTask(
      projectId: widget.projectId,
      taskId: widget.taskId,
      inboxTaskId: widget.inboxTaskId,
      scheduledAt: plannerInstant(_date, _time.hour, _time.minute),
      durationMinutes: _duration,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(
        context,
        _existing ? TaskScheduleResult.rescheduled : TaskScheduleResult.added,
      );
    } else {
      setState(
        () => _error =
            cubit.state.actionError ??
            'Не удалось сохранить время. Попробуйте ещё раз.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PlannerCubit, PlannerState>(
    builder: (context, state) {
      _prepare(state);
      final colors = Theme.of(context).colorScheme;
      final enabled = _prepared && !state.isSaving;
      final now = plannerNow();
      final today = plannerDate(now);
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final start = plannerLocal(
        plannerInstant(_date, _time.hour, _time.minute),
      );
      final end = start.add(Duration(minutes: _duration));
      final style = GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
      return PopScope(
        canPop: !state.isSaving,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _existing
                                    ? 'Изменить время'
                                    : 'Добавить в ежедневник',
                                style: GoogleFonts.manrope(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Закрыть',
                              onPressed: state.isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(LucideIcons.x, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Выделите время для этой задачи',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  LucideIcons.notebookPen,
                                  size: 20,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.source,
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: style.copyWith(
                                        color: colors.onSurface,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_prepared &&
                            state.status != PlannerStatus.failure) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(
                            minHeight: 2,
                            color: AppColors.accent,
                          ),
                        ],
                        if (!_prepared &&
                            state.status == PlannerStatus.failure) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.error ?? 'Не удалось загрузить ежедневник',
                            style: TextStyle(color: colors.error),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.read<PlannerCubit>().refresh(),
                            child: const Text('Повторить'),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'День',
                          style: style.copyWith(color: colors.onSurface),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in {
                              'Сегодня': today,
                              'Завтра': tomorrow,
                            }.entries)
                              ChoiceChip(
                                key: ValueKey('schedule-day-${entry.key}'),
                                label: Text(entry.key),
                                labelStyle: style.copyWith(fontSize: 13),
                                showCheckmark: false,
                                selected: samePlannerDay(_date, entry.value),
                                onSelected: enabled
                                    ? (_) => setState(() => _date = entry.value)
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _ScheduleField(
                          fieldKey: const Key('schedule-date'),
                          icon: LucideIcons.calendarDays,
                          label: 'Дата',
                          value: _dateLabel(_date),
                          enabled: enabled,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              helpText: 'День для задачи',
                              cancelText: 'Отмена',
                              confirmText: 'Готово',
                            );
                            if (mounted && date != null) {
                              setState(() => _date = date);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _ScheduleField(
                          fieldKey: const Key('schedule-time'),
                          icon: LucideIcons.clock3,
                          label: 'Начало',
                          value: plannerClock(start),
                          enabled: enabled,
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _time,
                              helpText: 'Время начала',
                              cancelText: 'Отмена',
                              confirmText: 'Готово',
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (mounted && time != null) {
                              setState(() => _time = time);
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Сколько времени выделить',
                          style: style.copyWith(color: colors.onSurface),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final minutes in ({
                              15,
                              30,
                              45,
                              60,
                              90,
                              120,
                              180,
                              _duration,
                            }.toList()..sort()))
                              ChoiceChip(
                                key: ValueKey('schedule-duration-$minutes'),
                                label: Text('$minutes мин'),
                                labelStyle: style.copyWith(fontSize: 13),
                                showCheckmark: false,
                                selected: _duration == minutes,
                                onSelected: enabled
                                    ? (_) => setState(() => _duration = minutes)
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_dateLabel(_date)} · ${plannerClock(start)}–${plannerClock(end)}${samePlannerDay(start, end) ? '' : ' (${_dateLabel(end)})'}',
                        key: const Key('schedule-summary'),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('schedule-confirm'),
                        onPressed: enabled ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: style,
                        ),
                        child: Text(
                          state.isSaving
                              ? 'Сохранение…'
                              : _existing
                              ? 'Сохранить время'
                              : 'Добавить в мой день',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });
  final Key fieldKey;
  final IconData icon;
  final String label, value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: fieldKey,
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 21, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) =>
    '${date.day} ${const ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'][date.month - 1]}';
