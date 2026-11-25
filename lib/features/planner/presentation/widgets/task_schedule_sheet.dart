import 'package:jospar/core/localization/app_translations.dart';
import 'planner_date_picker.dart';
import 'planner_time_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/utils/planner_dates.dart';
import '../cubit/planner_cubit.dart';
import '../cubit/planner_state.dart';
import 'planner_time_mode.dart';

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
  bool _hasTime = false;
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
    _date = plannerDate(now);
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
      _date = item.day ?? _date;
      _hasTime = item.scheduledAt != null;
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
      scheduledAt: _hasTime
          ? plannerInstant(_date, _time.hour, _time.minute)
          : null,
      plannedDate: _hasTime ? null : _date,
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
      final start = plannerLocal(
        plannerInstant(_date, _time.hour, _time.minute),
      );
      final style = GoogleFonts.inter(
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
                                    ? tr(context, 'Изменить план')
                                    : tr(context, 'Добавить в ежедневник'),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: tr(context, 'Закрыть'),
                              onPressed: state.isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(LucideIcons.x, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            context,
                            'Добавьте задачу в день. Время можно назначить позже.',
                          ),
                          style: GoogleFonts.inter(
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
                                      style: GoogleFonts.inter(
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
                            child: Text(tr(context, 'Повторить')),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          tr(context, 'День'),
                          style: style.copyWith(color: colors.onSurface),
                        ),
                        const SizedBox(height: 10),
                        _ScheduleField(
                          fieldKey: const Key('schedule-date'),
                          icon: LucideIcons.calendarDays,
                          label: 'Дата',
                          value: _dateLabel(_date),
                          enabled: enabled,
                          onTap: () async {
                            final date = await showPlannerDatePicker(
                              context: context,
                              initialDate: _date,
                            );
                            if (mounted && date != null) {
                              setState(() => _date = date);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        PlannerTimeMode(
                          hasTime: _hasTime,
                          onChanged: enabled
                              ? (value) => setState(() => _hasTime = value)
                              : null,
                        ),
                        if (_hasTime) ...[
                          const SizedBox(height: 12),
                          PlannerTimeField(
                            key: const Key('schedule-time'),
                            time: _time,
                            onChanged: enabled
                                ? (time) => setState(() => _time = time)
                                : null,
                          ),
                        ],
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
                        _hasTime
                            ? '${_dateLabel(_date)} · ${plannerClock(start)}'
                            : tr(context, "{p0} · Весь день", {
                                'p0': _dateLabel(_date),
                              }),
                        key: const Key('schedule-summary'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            tr(context, _error!),
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
                              ? tr(context, 'Сохранение…')
                              : _existing
                              ? tr(context, 'Сохранить план')
                              : tr(context, 'Добавить в мой день'),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF242424) : const Color(0xFFF7F7F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dark ? const Color(0xFF3C3C3C) : const Color(0xFFE5E5E5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: fieldKey,
        borderRadius: BorderRadius.circular(12),
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
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
