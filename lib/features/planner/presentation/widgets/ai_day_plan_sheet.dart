import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/ai_day_plan_entry.dart';
import '../../domain/repositories/ai_day_plan_repository.dart';
import '../../domain/repositories/planner_repository.dart';
import '../../domain/utils/planner_dates.dart';
import '../cubit/ai_day_plan_cubit.dart';

Future<void> showAiDayPlan(BuildContext context) async {
  final selection = sl<WorkspaceSelectionStorage>();
  final tokens = sl<AuthTokenStorage>();
  final workspace = await selection.read();
  final token = await tokens.read();
  if (!context.mounted || workspace == null || token == null) return;
  final cubit = AiDayPlanCubit(
    repository: sl<AiDayPlanRepository>(),
    planner: sl<PlannerRepository>(),
    workspaceId: workspace,
    day: plannerDate(plannerNow()),
    scopeIsCurrent: () async =>
        await selection.read() == workspace && await tokens.read() == token,
  );
  if (!context.mounted) {
    await cubit.close();
    return;
  }
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.of(context).canvas,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const AiDayPlanSheet()),
    );
  } finally {
    await cubit.close();
  }
}

class AiDayPlanSheet extends StatefulWidget {
  const AiDayPlanSheet({super.key});
  @override
  State<AiDayPlanSheet> createState() => _AiDayPlanSheetState();
}

class _AiDayPlanSheetState extends State<AiDayPlanSheet> {
  @override
  void initState() {
    super.initState();
    context.read<AiDayPlanCubit>().generate();
  }

  Future<void> _time(AiDayPlanEntry entry) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (entry.startMinute ?? 540) ~/ 60,
        minute: (entry.startMinute ?? 540) % 60,
      ),
    );
    if (!mounted || time == null) return;
    context.read<AiDayPlanCubit>().edit(
      entry.copyWith(startMinute: time.hour * 60 + time.minute),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AiDayPlanCubit, AiDayPlanState>(
    builder: (context, state) {
      final cubit = context.read<AiDayPlanCubit>();
      final saving = state.status == AiDayPlanStatus.saving;
      final ready = state.status == AiDayPlanStatus.ready;
      final complete = state.status == AiDayPlanStatus.complete;
      final total = state.entries
          .where((e) => e.selected)
          .fold<int>(0, (n, e) => n + e.durationMinutes);
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr(context, 'План дня через AI'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: tr(context, 'Закрыть'),
              onPressed: saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
      final subtitle = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          tr(context, 'На сегодня · {p0}', {'p0': plannerDayString(cubit.day)}),
        ),
      );
      final contents = <Widget>[
        if (state.status == AiDayPlanStatus.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  tr(context, 'Выбираем задачи с учётом сроков…'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          if (state.error != null) ...[
            Text(
              tr(context, state.error!),
              style: TextStyle(color: AppColors.of(context).error),
            ),
            const SizedBox(height: 12),
          ],
          if (state.status == AiDayPlanStatus.failure)
            OutlinedButton(
              onPressed: cubit.generate,
              child: Text(tr(context, 'Повторить')),
            )
          else if (state.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                tr(
                  context,
                  'Нет задач для предложения. AI выбирает из назначенных вам незавершённых задач, которые ещё не добавлены в ежедневник.',
                ),
              ),
            )
          else ...[
            Text(
              tr(
                context,
                complete
                    ? 'Выбранные задачи в ежедневнике. Существующие записи оставлены без изменений.'
                    : 'Уберите лишнее и при желании задайте время. Длительность — оценка AI; до подтверждения план не сохраняется.',
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in state.entries)
              _entry(context, entry, enabled: ready),
          ],
        ],
      ];
      final footer = state.entries.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(context, 'Выбрано: {p0} мин', {'p0': total}),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('ai-day-plan-confirm'),
                    onPressed: complete
                        ? () => Navigator.pop(context)
                        : ready && state.pendingCount > 0
                        ? cubit.confirm
                        : null,
                    child: Text(
                      tr(
                        context,
                        complete
                            ? 'Готово'
                            : saving
                            ? 'Добавляем…'
                            : 'Подтвердить план',
                      ),
                    ),
                  ),
                ],
              ),
            );
      return PopScope(
        canPop: !saving,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.85,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxHeight < 500 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                if (compact) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        subtitle,
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: contents,
                          ),
                        ),
                        footer,
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    subtitle,
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: contents,
                      ),
                    ),
                    footer,
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _entry(
    BuildContext context,
    AiDayPlanEntry entry, {
    required bool enabled,
  }) {
    final cubit = context.read<AiDayPlanCubit>();
    final editable = enabled && !entry.saved;
    final minute = entry.startMinute;
    return Padding(
      key: ValueKey('ai-plan-entry-${entry.taskId}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: entry.selected,
            onChanged: editable
                ? (value) => cubit.edit(entry.copyWith(selected: value))
                : null,
            title: Text(entry.title),
            subtitle: Text(
              entry.saved ? tr(context, 'Уже в ежедневнике') : entry.reason,
            ),
          ),
          if (entry.dueDate != null)
            Text(
              tr(context, 'Срок: {p0}', {
                'p0': plannerDayString(entry.dueDate!),
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (!entry.saved)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: editable && entry.selected
                      ? () => _time(entry)
                      : null,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    minute == null
                        ? tr(context, 'Без времени')
                        : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
                  ),
                ),
                if (minute != null)
                  IconButton(
                    tooltip: tr(context, 'Убрать время'),
                    onPressed: editable
                        ? () => cubit.edit(entry.copyWith(clearTime: true))
                        : null,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                DropdownButton<int>(
                  value: entry.durationMinutes,
                  isDense: false,
                  items:
                      ({
                            15,
                            30,
                            45,
                            60,
                            90,
                            120,
                            180,
                            entry.durationMinutes,
                          }.toList()..sort())
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(tr(context, '{p0} мин', {'p0': n})),
                            ),
                          )
                          .toList(),
                  onChanged: editable && entry.selected
                      ? (n) => cubit.edit(entry.copyWith(durationMinutes: n))
                      : null,
                ),
              ],
            ),
          const Divider(),
        ],
      ),
    );
  }
}
