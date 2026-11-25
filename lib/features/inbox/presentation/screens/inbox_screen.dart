import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/widgets/task_completion_indicator.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';
import '../../domain/entities/inbox_task_model.dart';
import '../cubit/inbox_cubit.dart';
import '../cubit/inbox_state.dart';
import '../widgets/inbox_task_menu.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.showAppBar = true, this.composeRequest});
  final String? composeRequest;

  final bool showAppBar;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusComposer();
  }

  @override
  void didUpdateWidget(InboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.composeRequest != widget.composeRequest) _focusComposer();
  }

  void _focusComposer() {
    if (widget.composeRequest == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _taskFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: widget.showAppBar ? const DashboardAppBar() : null,
      body: SafeArea(
        top: false,
        child: BlocBuilder<InboxCubit, InboxState>(
          builder: (context, state) => Column(
            children: <Widget>[
              Expanded(child: InboxContent(state: state)),
              QuickTaskComposer(
                controller: _taskController,
                focusNode: _taskFocusNode,
                isSubmitting: state.isCreating,
                onChanged: (_) => setState(() {}),
                onAdd: _addTask,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;
    final created = await context.read<InboxCubit>().create(title);
    if (!mounted) return;
    if (!created) {
      final message = context.read<InboxCubit>().state.creationErrorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.error,
          content: Text(message ?? 'Не удалось создать задачу.'),
        ),
      );
      return;
    }
    _taskController.clear();
    setState(() {});
    _taskFocusNode.requestFocus();
  }
}

class InboxContent extends StatelessWidget {
  const InboxContent({super.key, required this.state});

  final InboxState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (state.status) {
        InboxStatus.initial || InboxStatus.loading => const InboxLoading(
          key: ValueKey<String>('loading'),
        ),
        InboxStatus.failure => InboxFailure(
          key: const ValueKey<String>('failure'),
          message: state.errorMessage ?? 'Не удалось загрузить задачи.',
          onRetry: context.read<InboxCubit>().load,
        ),
        InboxStatus.success when state.tasks.isEmpty => RefreshableInboxEmpty(
          key: const ValueKey<String>('empty'),
          onRefresh: context.read<InboxCubit>().load,
        ),
        InboxStatus.success => RefreshIndicator(
          key: const ValueKey<String>('tasks'),
          color: AppColors.accent,
          onRefresh: context.read<InboxCubit>().load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: InboxHeader(taskCount: state.tasks.length),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList.separated(
                  itemCount: state.tasks.length,
                  separatorBuilder: (context, index) => Divider(
                    height: AppSpacing.xxs,
                    thickness: AppSpacing.xxs / 2,
                    color: AppColors.of(context).border,
                  ),
                  itemBuilder: (context, index) {
                    final task = state.tasks[index];
                    return InboxTaskRow(
                      key: ValueKey<String>(task.id),
                      task: task,
                      isCompleting: state.completingTaskIds.contains(task.id),
                      onToggle: () => task.isLocalOnly
                          ? context.read<InboxCubit>().toggleLocal(task.id)
                          : completeTask(context, task.id),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      },
    );
  }

  Future<void> completeTask(BuildContext context, String taskId) async {
    final cubit = context.read<InboxCubit>();
    final completed = await cubit.complete(taskId);
    if (!context.mounted || completed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context: context,
        tone: AppSnackBarTone.error,
        content: Text(
          cubit.state.completionErrorMessage ?? 'Не удалось завершить задачу.',
        ),
      ),
    );
  }
}

class InboxHeader extends StatelessWidget {
  const InboxHeader({super.key, required this.taskCount});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.mdLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  'Inbox',
                  style: AppTypography.pageTitle(
                    context,
                  )?.copyWith(color: AppColors.of(context).ink),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TaskCount(count: taskCount),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr(
              context,
              'Свайп вправо — в ежедневник, влево — в проект или удалить.',
            ),
            style: AppTypography.body(
              context,
            )?.copyWith(color: AppColors.of(context).muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class InboxTaskRow extends StatelessWidget {
  const InboxTaskRow({
    super.key,
    required this.task,
    required this.isCompleting,
    required this.onToggle,
  });

  final InboxTaskModel task;
  final bool isCompleting;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('inbox-swipe-${task.id}'),
      direction: isCompleting
          ? DismissDirection.none
          : task.isLocalOnly
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      resizeDuration: null,
      confirmDismiss: (direction) async {
        await sortInboxTask(
          context,
          task,
          schedule: direction == DismissDirection.startToEnd,
        );
        return false;
      },
      background: const _InboxSwipeHint(schedule: true),
      secondaryBackground: const _InboxSwipeHint(schedule: false),
      child: Semantics(
        container: true,
        label: tr(context, "Задача: {p0}", {'p0': task.title}),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.smMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CompletionButton(
                task: task,
                isCompleting: isCompleting,
                onToggle: onToggle,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: InkWell(
                  onTap: isCompleting
                      ? null
                      : () => showInboxTaskCard(context, task),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          task.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.taskTitle(context)?.copyWith(
                            color: task.completed
                                ? AppColors.of(context).muted
                                : AppColors.of(context).ink,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const TaskMetadata(),
                      ],
                    ),
                  ),
                ),
              ),
              InboxTaskMenu(task: task, busy: isCompleting),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxSwipeHint extends StatelessWidget {
  const _InboxSwipeHint({required this.schedule});
  final bool schedule;

  @override
  Widget build(BuildContext context) => Container(
    alignment: schedule
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    color: AppColors.accent.withValues(alpha: 0.1),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          schedule ? Icons.event_outlined : Icons.drive_file_move_outline,
          color: AppColors.accent,
        ),
        const SizedBox(height: 4),
        Text(
          tr(context, schedule ? 'В ежедневник' : 'В проект'),
          style: TextStyle(color: AppColors.accent),
        ),
      ],
    ),
  );
}

class CompletionButton extends StatelessWidget {
  const CompletionButton({
    super.key,
    required this.task,
    required this.isCompleting,
    required this.onToggle,
  });

  final InboxTaskModel task;
  final bool isCompleting;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final label = task.completed ? 'Вернуть в работу' : 'Завершить задачу';
    return Semantics(
      button: true,
      checked: task.completed,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: Key('inbox-task-checkbox-${task.id}'),
          onTap: isCompleting ? null : onToggle,
          radius: AppSpacing.lg,
          child: SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: Center(
              child: TaskCompletionIndicator(
                completed: task.completed,
                busy: isCompleting,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TaskMetadata extends StatelessWidget {
  const TaskMetadata({super.key});

  @override
  Widget build(BuildContext context) {
    final metadataStyle = AppTypography.caption(context)?.copyWith(
      color: AppColors.of(context).muted,
      fontWeight: FontWeight.w500,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final project = ProjectMetadata(style: metadataStyle);
        const badge = InboxBadge();
        if (constraints.maxWidth < 220) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              project,
              const SizedBox(height: AppSpacing.sm),
              badge,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Flexible(child: project),
            const SizedBox(width: AppSpacing.sm),
            badge,
          ],
        );
      },
    );
  }
}

class ProjectMetadata extends StatelessWidget {
  const ProjectMetadata({super.key, required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.folder_outlined,
          size: AppIconSizes.standard,
          color: AppColors.of(context).muted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            tr(context, 'Не распределена'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class InboxBadge extends StatelessWidget {
  const InboxBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        tr(context, 'ИНБОКС'),
        style: AppTypography.caption(context)?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class QuickTaskComposer extends StatelessWidget {
  const QuickTaskComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onChanged,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final canAdd = controller.text.trim().isNotEmpty && !isSubmitting;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.of(context).canvas,
        border: Border(top: BorderSide(color: AppColors.of(context).border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.smMd,
          AppSpacing.md,
          AppSpacing.smMd + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.touchTarget + AppSpacing.sm,
          ),
          padding: const EdgeInsets.only(
            left: AppSpacing.smMd,
            right: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.of(context).quietSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.of(context).border),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.add_task_rounded,
                size: AppIconSizes.standard,
                color: AppColors.of(context).muted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: const Key('inbox-task-input'),
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: (_) => canAdd ? onAdd() : null,
                  readOnly: isSubmitting,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  style: AppTypography.body(
                    context,
                  )?.copyWith(color: AppColors.of(context).ink),
                  decoration: InputDecoration(
                    hintText: tr(context, 'Добавить быструю задачу'),
                    hintStyle: AppTypography.body(
                      context,
                    )?.copyWith(color: AppColors.of(context).muted),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: IconButton.filled(
                  key: const Key('inbox-add-task'),
                  tooltip: tr(context, 'Добавить задачу'),
                  onPressed: canAdd ? onAdd : null,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(AppSpacing.touchTarget),
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.of(context).skeleton,
                    foregroundColor: AppColors.onAccent,
                    disabledForegroundColor: AppColors.of(context).muted,
                  ),
                  icon: isSubmitting
                      ? const SizedBox.square(
                          dimension: AppSpacing.md,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSpacing.xxs,
                            color: AppColors.onAccent,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          size: AppIconSizes.standard,
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

class TaskCount extends StatelessWidget {
  const TaskCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: AppSpacing.xl,
        minHeight: AppSpacing.xl,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '$count',
        style: AppTypography.body(
          context,
        )?.copyWith(fontWeight: FontWeight.w700, color: AppColors.accent),
      ),
    );
  }
}

class InboxLoading extends StatelessWidget {
  const InboxLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: <Widget>[
        const SliverToBoxAdapter(child: InboxHeader(taskCount: 0)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (context, index) => Divider(
              height: AppSpacing.xxs,
              color: AppColors.of(context).border,
            ),
            itemBuilder: (context, index) => const InboxTaskSkeleton(),
          ),
        ),
      ],
    );
  }
}

class InboxTaskSkeleton extends StatelessWidget {
  const InboxTaskSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: AppSpacing.smMd,
            backgroundColor: AppColors.of(context).skeleton,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FractionallySizedBox(
                  widthFactor: 0.72,
                  child: Container(
                    height: AppSpacing.md,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).skeleton,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.48,
                  child: Container(
                    height: AppSpacing.smMd,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).skeletonTrack,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InboxFailure extends StatelessWidget {
  const InboxFailure({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_rounded,
              size: AppSpacing.touchTarget,
              color: AppColors.of(context).muted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                context,
              )?.copyWith(color: AppColors.of(context).muted, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: const Key('inbox-retry'),
              onPressed: onRetry,
              child: Text(tr(context, 'Повторить')),
            ),
          ],
        ),
      ),
    );
  }
}

class RefreshableInboxEmpty extends StatelessWidget {
  const RefreshableInboxEmpty({super.key, required this.onRefresh});

  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        color: AppColors.accent,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: <Widget>[
            const InboxHeader(taskCount: 0),
            SizedBox(
              height: (constraints.maxHeight - 120).clamp(0, double.infinity),
              child: const InboxEmpty(),
            ),
          ],
        ),
      ),
    );
  }
}

class InboxEmpty extends StatelessWidget {
  const InboxEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationSize = constraints.maxHeight < 320 ? 112.0 : 200.0;
        final colors = Theme.of(context).colorScheme;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/inbox_empty.png',
                  key: const Key('inbox-empty-illustration'),
                  width: illustrationSize,
                  height: illustrationSize,
                  cacheWidth: 640,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  tr(context, 'Инбокс разобран'),
                  textAlign: TextAlign.center,
                  style: AppTypography.title(
                    context,
                  )?.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    tr(
                      context,
                      'Быстро добавляйте сюда новые задачи, а позже распределяйте их по проектам.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      context,
                    )?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
