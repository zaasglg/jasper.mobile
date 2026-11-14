import '../../../../core/theme/app_ui_tokens.dart';
import 'task_detail_style.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/task_details_cubit.dart';

class TaskTimingPanel extends StatefulWidget {
  const TaskTimingPanel({super.key, required this.cubit, required this.onEdit});
  final TaskDetailsCubit cubit;
  final VoidCallback onEdit;
  @override
  State<TaskTimingPanel> createState() => _TaskTimingPanelState();
}

class _TaskTimingPanelState extends State<TaskTimingPanel> {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.cubit.state.task?.timerStartedAt != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.cubit.state;
    final task = state.task!;
    final minutes =
        state.detail.estimateMinutes ?? (task.estimate * 60).round();
    final running = task.timerStartedAt != null;
    final activeMs = running
        ? DateTime.now().difference(task.timerStartedAt!).inMilliseconds
        : 0;
    final elapsed = Duration(
      milliseconds: task.timerElapsedMs + (activeMs < 0 ? 0 : activeMs),
    );
    String pad(int value) => value.toString().padLeft(2, '0');
    String durationLabel(Duration duration, {bool seconds = false}) {
      final parts = <String>[
        if (duration.inHours > 0) '${duration.inHours} ч',
        if (duration.inMinutes % 60 > 0) '${duration.inMinutes % 60} м',
        if (seconds && duration.inSeconds % 60 > 0)
          '${duration.inSeconds % 60} с',
      ];
      if (parts.isEmpty) return seconds ? '0 с' : '0 ч';
      if (!seconds && duration.inHours == 0) parts.insert(0, '0 ч');
      return parts.join(' ');
    }

    final estimate = Duration(minutes: minutes);
    final overtime = minutes > 0 && elapsed.inSeconds > estimate.inSeconds;
    final summary = overtime
        ? '+${durationLabel(elapsed - estimate, seconds: true)}'
        : durationLabel(elapsed);
    final clock =
        '${pad(elapsed.inHours)} ч : ${pad(elapsed.inMinutes % 60)} м : ${pad(elapsed.inSeconds % 60)} с';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('ТАЙМИНГ', style: TaskDetailStyle.label(context)),
        ),
        Material(
          color: TaskDetailStyle.field(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: state.isSaving ? null : widget.onEdit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  durationLabel(estimate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.edit_outlined,
                                size: AppIconSizes.standard,
                                color: AppColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Tooltip(
                        message: overtime ? 'Переработка' : 'Затраченное время',
                        child: Center(
                          child: Text(
                            summary,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: overtime ? AppColors.error : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        clock,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('task-timer-toggle'),
                      tooltip: running
                          ? 'Приостановить таймер'
                          : 'Запустить таймер',
                      onPressed: state.isSaving || !task.isTimingEnabled
                          ? null
                          : () => widget.cubit.timerAction(
                              running ? 'pause' : 'start',
                            ),
                      icon: Icon(
                        running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_outlined,
                        size: AppIconSizes.standard,
                        color: AppColors.muted,
                      ),
                    ),
                    IconButton(
                      key: const Key('task-timer-reset'),
                      tooltip: 'Сбросить таймер',
                      onPressed: state.isSaving
                          ? null
                          : () => widget.cubit.timerAction('reset'),
                      icon: const Icon(
                        Icons.restart_alt,
                        size: AppIconSizes.standard,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
