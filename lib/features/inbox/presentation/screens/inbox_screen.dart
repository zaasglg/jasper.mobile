import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/screens/main_shell.dart';
import '../../data/models/inbox_task_model.dart';
import '../cubit/inbox_cubit.dart';
import '../cubit/inbox_state.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode();

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Открыть меню',
          onPressed: MainShell.openDrawer,
          icon: const Icon(Icons.menu_rounded, color: AppColors.ink),
        ),
        title: Text(
          'Инбокс',
          style: GoogleFonts.manrope(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.35,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<InboxCubit, InboxState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Неразобранные',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TaskCount(count: state.tasks.length),
                  ],
                ),
              ),
              Expanded(child: _InboxContent(state: state)),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: _QuickTaskComposer(
                  controller: _taskController,
                  focusNode: _taskFocusNode,
                  onChanged: (_) => setState(() {}),
                  onAdd: _addTask,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addTask() {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;
    context.read<InboxCubit>().addLocal(title);
    _taskController.clear();
    setState(() {});
    _taskFocusNode.requestFocus();
  }
}

class _InboxContent extends StatelessWidget {
  const _InboxContent({required this.state});

  final InboxState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (state.status) {
        InboxStatus.initial || InboxStatus.loading => const _InboxLoading(
          key: ValueKey<String>('loading'),
        ),
        InboxStatus.failure => _InboxFailure(
          key: const ValueKey<String>('failure'),
          message: state.errorMessage ?? 'Не удалось загрузить задачи.',
          onRetry: context.read<InboxCubit>().load,
        ),
        InboxStatus.success when state.tasks.isEmpty => _RefreshableEmpty(
          key: const ValueKey<String>('empty'),
          onRefresh: context.read<InboxCubit>().load,
        ),
        InboxStatus.success => RefreshIndicator(
          key: const ValueKey<String>('tasks'),
          color: AppColors.accent,
          onRefresh: context.read<InboxCubit>().load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 28),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: state.tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final task = state.tasks[index];
              return _QuickTaskTile(
                key: ValueKey<String>(task.id),
                task: task,
                onToggle: task.isLocalOnly
                    ? () => context.read<InboxCubit>().toggleLocal(task.id)
                    : null,
                onDelete: task.isLocalOnly
                    ? () => context.read<InboxCubit>().removeLocal(task.id)
                    : null,
              );
            },
          ),
        ),
      },
    );
  }
}

class _InboxLoading extends StatelessWidget {
  const _InboxLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 28),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (_, _) => Container(
        height: 112,
        decoration: BoxDecoration(
          color: AppColors.subtleSurface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _InboxFailure extends StatelessWidget {
  const _InboxFailure({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              key: const Key('inbox-retry'),
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshableEmpty extends StatelessWidget {
  const _RefreshableEmpty({super.key, required this.onRefresh});

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
            SizedBox(
              height: constraints.maxHeight,
              child: const _QuickTasksEmpty(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTaskComposer extends StatelessWidget {
  const _QuickTaskComposer({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final canAdd = controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 4, 5, 4),
      decoration: BoxDecoration(
        color: AppColors.subtleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.add_task_rounded, size: 21, color: AppColors.muted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              key: const Key('inbox-task-input'),
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => canAdd ? onAdd() : null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.manrope(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Добавить быструю задачу',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: IconButton.filled(
              key: const Key('inbox-add-task'),
              tooltip: 'Добавить задачу',
              onPressed: canAdd ? onAdd : null,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(38),
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.skeleton,
                foregroundColor: Colors.white,
                disabledForegroundColor: AppColors.muted,
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTaskTile extends StatelessWidget {
  const _QuickTaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final InboxTaskModel task;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 12),
      decoration: BoxDecoration(
        color: task.completed ? const Color(0xFFF4F8F4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ИНБОКС',
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.45,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              if (onDelete != null)
                PopupMenuButton<_QuickTaskAction>(
                  tooltip: 'Действия задачи',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 150),
                  position: PopupMenuPosition.under,
                  onSelected: (action) {
                    if (action == _QuickTaskAction.delete) onDelete?.call();
                  },
                  itemBuilder: (context) =>
                      const <PopupMenuEntry<_QuickTaskAction>>[
                        PopupMenuItem<_QuickTaskAction>(
                          value: _QuickTaskAction.delete,
                          child: Text('Удалить'),
                        ),
                      ],
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                )
              else
                const SizedBox(height: 40),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: task.completed ? AppColors.muted : AppColors.ink,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              Tooltip(
                message: task.completed
                    ? 'Вернуть в работу'
                    : 'Завершить задачу',
                child: InkWell(
                  key: Key('inbox-task-checkbox-${task.id}'),
                  onTap: onToggle,
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: task.completed
                          ? AppColors.success
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.completed
                            ? AppColors.success
                            : AppColors.muted,
                        width: 1.6,
                      ),
                    ),
                    child: task.completed
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Icon(
                Icons.folder_open_rounded,
                size: 15,
                color: AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                'Не распределена',
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _QuickTaskAction { delete }

class _TaskCount extends StatelessWidget {
  const _TaskCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 22),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.badgeSurface,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _QuickTasksEmpty extends StatelessWidget {
  const _QuickTasksEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 76),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.075),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.playlist_add_rounded,
                size: 29,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Запишите первую задачу',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.25,
              ),
            ),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 285),
              child: Text(
                'Инбокс хранит быстрые задачи, пока вы не распределите их по проектам.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
