import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/task_completion_indicator.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';
import '../../../tasks/presentation/widgets/task_detail_style.dart';
import '../../domain/entities/inbox_task_model.dart';
import '../cubit/inbox_cubit.dart';
import '../cubit/inbox_state.dart';
import '../widgets/inbox_task_menu.dart';

class InboxTaskDetailsScreen extends StatelessWidget {
  const InboxTaskDetailsScreen({
    super.key,
    required this.taskId,
    this.initialTask,
    this.showAppBar = true,
  });
  final String taskId;
  final InboxTaskModel? initialTask;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) => BlocBuilder<InboxCubit, InboxState>(
    builder: (context, state) {
      final cubit = context.read<InboxCubit>();
      final task =
          state.tasks.where((e) => e.id == taskId).firstOrNull ??
          (state.status == InboxStatus.success ? null : initialTask);
      final busy = state.completingTaskIds.contains(taskId);
      Future<void> edit() async {
        if (task != null) await editInboxTaskCard(context, task);
      }

      return Scaffold(
        appBar: showAppBar ? const DashboardAppBar() : null,
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  AppBackButton(onPressed: () => context.pop()),
                  Expanded(
                    child: Text(
                      task?.displayId.isNotEmpty == true
                          ? task!.displayId
                          : tr(context, 'Инбокс'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (task != null) InboxTaskMenu(task: task, busy: busy),
                  IconButton(
                    tooltip: tr(context, 'Обновить'),
                    onPressed: state.status == InboxStatus.loading
                        ? null
                        : cubit.load,
                    icon: const Icon(LucideIcons.refreshCw, size: 20),
                  ),
                ],
              ),
              if (state.status == InboxStatus.loading)
                const LinearProgressIndicator(),
              Expanded(
                child: task == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.status == InboxStatus.failure
                                  ? tr(context, 'Не удалось загрузить задачу')
                                  : tr(
                                      context,
                                      'Задача недоступна или перемещена',
                                    ),
                            ),
                            TextButton(
                              onPressed: cubit.load,
                              child: Text(tr(context, 'Повторить')),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              avatar: Icon(LucideIcons.inbox, size: 16),
                              label: Text(tr(context, 'Инбокс')),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                tooltip: tr(context, 'Завершить задачу'),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        if (task.isLocalOnly) {
                                          cubit.toggleLocal(task.id);
                                          return;
                                        }
                                        final success = await cubit.complete(
                                          task.id,
                                        );
                                        if (!context.mounted) return;
                                        if (success) {
                                          context.pop();
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            appSnackBar(
                                              context: context,
                                              tone: AppSnackBarTone.error,
                                              content: Text(
                                                cubit
                                                        .state
                                                        .completionErrorMessage ??
                                                    'Не удалось завершить задачу',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                icon: TaskCompletionIndicator(
                                  completed: task.completed,
                                  busy: busy,
                                  size: 24,
                                ),
                              ),
                              Expanded(
                                child: TextButton(
                                  onPressed: task.isLocalOnly ? null : edit,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 48),
                                    alignment: Alignment.centerLeft,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  child: Text(
                                    task.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr(context, 'Описание'),
                            style: TaskDetailStyle.heading(context),
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            icon: LucideIcons.alignLeft,
                            label: 'Описание',
                            value:
                                task.detail.description ??
                                task.description ??
                                'Добавить описание…',
                            onTap: task.isLocalOnly ? null : edit,
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final fields = [
                                _Field(
                                  icon: LucideIcons.calendar,
                                  label: 'Начало',
                                  value: task.start ?? 'Не задано',
                                  onTap: task.isLocalOnly ? null : edit,
                                ),
                                _Field(
                                  icon: LucideIcons.calendarClock,
                                  label: 'Срок',
                                  value: task.end ?? 'Не задан',
                                  onTap: task.isLocalOnly ? null : edit,
                                ),
                              ];
                              if (constraints.maxWidth < 340 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.4) {
                                return Column(
                                  children: [
                                    fields[0],
                                    const SizedBox(height: 12),
                                    fields[1],
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: fields[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: fields[1]),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            tr(context, 'Метки'),
                            style: TaskDetailStyle.heading(context),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final label in task.detail.labels ?? [])
                                Chip(label: Text(label.text ?? '')),
                              if (!task.isLocalOnly)
                                ActionChip(
                                  avatar: const Icon(
                                    LucideIcons.plus,
                                    size: 16,
                                  ),
                                  label: Text(tr(context, 'Изменить')),
                                  onPressed: edit,
                                ),
                            ],
                          ),
                          if (state.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(tr(context, state.errorMessage!)),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: TaskDetailStyle.field(context),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: TaskDetailStyle.label(context)),
                ),
                if (onTap != null) const Icon(LucideIcons.pencil, size: 16),
              ],
            ),
            const SizedBox(height: 20),
            Text(value),
          ],
        ),
      ),
    ),
  );
}
