import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import 'task_card.dart';
import '../cubit/kanban_cubit.dart';
import '../cubit/kanban_state.dart';

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({required this.project, super.key});

  final ProjectModel project;

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  static const double _columnViewportFraction = 0.98;
  static const double _columnHorizontalInset = 4;

  final PageController _horizontalController = PageController(
    viewportFraction: _columnViewportFraction,
  );

  final _archiveTarget = GlobalKey();
  final _moveTarget = GlobalKey();
  ProjectTaskModel? _draggedTask;
  _TaskDropAction? _hoveredAction;
  bool _dragCancelled = false;

  void _updateDropTarget(PointerMoveEvent event) {
    if (_draggedTask == null) return;
    _TaskDropAction? action;
    for (final entry in {
      _TaskDropAction.archive: _archiveTarget,
      _TaskDropAction.move: _moveTarget,
    }.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).contains(
            event.position,
          )) {
        action = entry.key;
      }
    }
    if (_hoveredAction != action) setState(() => _hoveredAction = action);
  }

  void _startTaskDrag(ProjectTaskModel task) {
    setState(() {
      _draggedTask = task;
      _hoveredAction = null;
      _dragCancelled = false;
    });
  }

  bool _endTaskDrag() {
    final task = _draggedTask;
    final action = _hoveredAction;
    final cancelled = _dragCancelled;
    setState(() {
      _draggedTask = null;
      _hoveredAction = null;
    });
    if (!cancelled && task != null && action != null) {
      // Let the reorder proxy finish its drop animation before opening a sheet.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || widget.project.id != task.projectId) return;
        final cubit = context.read<KanbanCubit>();
        if (action == _TaskDropAction.move) {
          _showMoveTask(context, task, cubit.state);
        } else {
          cubit.archiveTask(task);
        }
      });
    }
    return cancelled || action != null;
  }

  @override
  void didUpdateWidget(covariant KanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id == widget.project.id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalController.hasClients) {
        _horizontalController.jumpToPage(0);
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KanbanCubit, KanbanState>(
      listenWhen: (previous, current) =>
          previous.actionRevision != current.actionRevision,
      listener: (context, state) {
        final message = state.actionErrorMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      builder: (context, state) {
        return Listener(
          onPointerMove: _updateDropTarget,
          onPointerCancel: (_) {
            _dragCancelled = true;
            if (_draggedTask != null) _endTaskDrag();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 52,
                child: _draggedTask == null
                    ? _BoardToolbar(
                        onAddColumn: () => _showCreateColumn(context),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _TaskDropZone(
                              key: _archiveTarget,
                              label: 'Архив',
                              icon: LucideIcons.archive,
                              active: _hoveredAction == _TaskDropAction.archive,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TaskDropZone(
                              key: _moveTarget,
                              label: 'Переместить',
                              icon: LucideIcons.arrowRightLeft,
                              active: _hoveredAction == _TaskDropAction.move,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _boardContent(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _boardContent(BuildContext context, KanbanState state) {
    if (state.status == KanbanStatus.loading && state.columns.isEmpty) {
      return const _BoardSkeleton();
    }
    if (state.status == KanbanStatus.failure) {
      return _BoardMessage(
        icon: LucideIcons.circleAlert,
        message: state.errorMessage ?? 'Не удалось загрузить доску',
        action: () =>
            context.read<KanbanCubit>().load(widget.project.id, refresh: true),
      );
    }
    if (state.columns.isEmpty) {
      return _BoardMessage(
        icon: LucideIcons.columns3,
        message: 'На этой доске пока нет колонок',
        actionLabel: 'Добавить колонку',
        action: () => _showCreateColumn(context),
      );
    }
    return PageView.builder(
      key: PageStorageKey<String>('kanban-${widget.project.id}'),
      controller: _horizontalController,
      scrollDirection: Axis.horizontal,
      padEnds: true,
      pageSnapping: true,
      physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: state.columns.length,
      itemBuilder: (context, index) {
        final column = state.columns[index];
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            _columnHorizontalInset,
            0,
            _columnHorizontalInset,
            2,
          ),
          child: _KanbanColumn(
            key: ValueKey('${widget.project.id}-${column.id}'),
            column: column,
            canReorder:
                state.movingTaskIds.isEmpty &&
                state.search.trim().isEmpty &&
                state.priorityFilter == null,
            tasks: state.tasksFor(column),
            exceedsWip: state.exceedsWip(column),
            onAddTask: (title) => context.read<KanbanCubit>().createTask(
              column.statusMap,
              title,
              'MED',
            ),
            onMove: (task, position) => context.read<KanbanCubit>().moveTask(
              task,
              column.statusMap,
              position,
            ),
            onDragStart: _startTaskDrag,
            onDragEnd: _endTaskDrag,
            onManage: (action) => _manageColumn(context, column, action),
          ),
        );
      },
    );
  }

  Future<void> _showCreateColumn(BuildContext context) async {
    final result = await showModalBottomSheet<(String, int?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateColumnSheet(),
    );
    if (result != null && context.mounted) {
      await context.read<KanbanCubit>().createColumn(result.$1, result.$2);
    }
  }

  Future<void> _showMoveTask(
    BuildContext context,
    ProjectTaskModel task,
    KanbanState state,
  ) async {
    final result = await showModalBottomSheet<(String, int)>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MoveTaskSheet(state: state, task: task),
    );
    if (result != null && context.mounted) {
      await context.read<KanbanCubit>().moveTask(task, result.$1, result.$2);
    }
  }

  Future<void> _manageColumn(
    BuildContext context,
    KanbanColumnModel column,
    _ColumnAction action,
  ) async {
    final cubit = context.read<KanbanCubit>();
    switch (action) {
      case _ColumnAction.moveLeft:
        await cubit.moveColumn(column, -1);
      case _ColumnAction.moveRight:
        await cubit.moveColumn(column, 1);
      case _ColumnAction.rename:
        final result = await showModalBottomSheet<(String, int?)>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _EditColumnSheet(column: column),
        );
        if (result != null && context.mounted) {
          await cubit.updateColumn(column, result.$1, result.$2);
        }
      case _ColumnAction.archive:
        await cubit.archiveColumn(column);
      case _ColumnAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Удалить колонку?'),
            content: Text(
              'Колонка «${column.name}» будет удалена. Сервер проверит, можно ли выполнить это действие.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
        if (confirmed == true) await cubit.deleteColumn(column);
    }
  }
}

enum _TaskDropAction { archive, move }

class _TaskDropZone extends StatelessWidget {
  const _TaskDropZone({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
  });
  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      color: active
          ? AppColors.accent
          : AppColors.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: active
            ? AppColors.accent
            : AppColors.accent.withValues(alpha: 0.25),
      ),
    ),
    alignment: Alignment.center,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: active ? Colors.white : AppColors.accent),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.accent,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BoardToolbar extends StatelessWidget {
  const _BoardToolbar({required this.onAddColumn});

  final VoidCallback onAddColumn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                onChanged: context.read<KanbanCubit>().setSearch,
                decoration: InputDecoration(
                  hintText: 'Поиск задач',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  filled: true,
                  fillColor: AppColors.subtleSurface,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Добавить колонку',
              onPressed: onAddColumn,
              style: IconButton.styleFrom(backgroundColor: AppColors.accent),
              icon: const Icon(LucideIcons.plus, color: Colors.white, size: 19),
            ),
          ],
        ),
      ],
    );
  }
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    super.key,
    required this.column,
    required this.canReorder,
    required this.tasks,
    required this.exceedsWip,
    required this.onAddTask,
    required this.onMove,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onManage,
  });

  final KanbanColumnModel column;
  final bool canReorder;
  final List<ProjectTaskModel> tasks;
  final bool exceedsWip;
  final Future<void> Function(String title) onAddTask;
  final void Function(ProjectTaskModel task, int position) onMove;
  final ValueChanged<ProjectTaskModel> onDragStart;
  final bool Function() onDragEnd;
  final ValueChanged<_ColumnAction> onManage;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  static const Duration _composerAnimationDuration = Duration(
    milliseconds: 240,
  );
  static const Duration _keyboardDelay = Duration(milliseconds: 100);

  final TextEditingController _taskTitleController = TextEditingController();
  final FocusNode _taskTitleFocusNode = FocusNode();

  final _columnBounds = GlobalKey();
  final _dragVisual = ValueNotifier<(double, bool)>((0, false));
  double _pointerStartX = 0;
  bool _isDragging = false;

  void _trackDrag(PointerMoveEvent event) {
    if (!_isDragging) return;
    final box = _columnBounds.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final outside = !(box.localToGlobal(Offset.zero) & box.size).contains(
      event.position,
    );
    // Flutter handles vertical movement; add the pointer's horizontal movement
    // only outside the column, keeping normal list reordering aligned.
    _dragVisual.value = (
      outside ? event.position.dx - _pointerStartX : 0,
      outside,
    );
  }

  bool _skipReorder = false;
  bool _isAddingTask = false;
  bool _isSubmittingTask = false;

  @override
  void dispose() {
    _dragVisual.dispose();
    _taskTitleController.dispose();
    _taskTitleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openTaskComposer() async {
    if (_isAddingTask) return;
    setState(() => _isAddingTask = true);
    await Future<void>.delayed(_keyboardDelay);
    if (mounted && _isAddingTask) _taskTitleFocusNode.requestFocus();
  }

  void _closeTaskComposer() {
    _taskTitleFocusNode.unfocus();
    _taskTitleController.clear();
    setState(() => _isAddingTask = false);
  }

  Future<void> _submitTask() async {
    final title = _taskTitleController.text.trim();
    if (title.isEmpty || _isSubmittingTask) {
      _taskTitleFocusNode.requestFocus();
      return;
    }

    setState(() => _isSubmittingTask = true);
    await widget.onAddTask(title);
    if (!mounted) return;

    _taskTitleController.clear();
    _taskTitleFocusNode.unfocus();
    setState(() {
      _isAddingTask = false;
      _isSubmittingTask = false;
    });
  }

  Future<void> _showColumnMenu() async {
    final action = await showCupertinoModalPopup<_ColumnAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: <Widget>[
          _columnAction(
            sheetContext,
            action: _ColumnAction.moveLeft,
            label: 'Переместить левее',
          ),
          _columnAction(
            sheetContext,
            action: _ColumnAction.moveRight,
            label: 'Переместить правее',
          ),
          _columnAction(
            sheetContext,
            action: _ColumnAction.rename,
            label: 'Переименовать',
          ),
          _columnAction(
            sheetContext,
            action: _ColumnAction.archive,
            label: 'Архивировать',
          ),
          _columnAction(
            sheetContext,
            action: _ColumnAction.delete,
            label: 'Удалить',
            isDestructive: true,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Отмена'),
        ),
      ),
    );

    if (action != null && mounted) widget.onManage(action);
  }

  Widget _columnAction(
    BuildContext sheetContext, {
    required _ColumnAction action,
    required String label,
    bool isDestructive = false,
  }) {
    return CupertinoActionSheetAction(
      isDestructiveAction: isDestructive,
      onPressed: () => Navigator.pop(sheetContext, action),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columnColor = _parseColumnColor(widget.column.color);
    final columnBackground = Color.alphaBlend(
      columnColor.withValues(alpha: isDark ? 0.22 : 0.15),
      colors.surface,
    );
    final headerColor = Color.lerp(columnColor, colors.onSurface, 0.58)!;
    final wip = widget.column.wip;
    return Listener(
      onPointerDown: (event) => _pointerStartX = event.position.dx,
      onPointerMove: _trackDrag,
      onPointerCancel: (_) {
        _isDragging = false;
        _dragVisual.value = (0, false);
      },
      child: AnimatedContainer(
        key: _columnBounds,
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: columnBackground,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 8, 13),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.column.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.25,
                        color: headerColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: widget.exceedsWip
                          ? AppColors.error
                          : columnColor.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      wip == null
                          ? '${widget.tasks.length}'
                          : '${widget.tasks.length} / $wip',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Действия колонки',
                    onPressed: _showColumnMenu,
                    icon: Icon(
                      LucideIcons.ellipsis,
                      size: 17,
                      color: headerColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.tasks.isEmpty
                  ? const _EmptyColumn()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      buildDefaultDragHandles: false,
                      autoScrollerVelocityScalar: 45,
                      itemCount: widget.tasks.length,
                      proxyDecorator: (child, index, animation) =>
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              animation,
                              _dragVisual,
                            ]),
                            child: child,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                _dragVisual.value.$1 *
                                    (_isDragging ? 1 : animation.value),
                                0,
                              ),
                              child: Opacity(
                                opacity: _dragVisual.value.$2 ? 0.65 : 1,
                                child: Material(
                                  color: Colors.transparent,
                                  elevation:
                                      6 *
                                      Curves.easeOutCubic.transform(
                                        animation.value,
                                      ),
                                  shadowColor: AppColors.ink.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                      dragBoundaryProvider: (_) => null,
                      onReorderStart: (index) {
                        _skipReorder = false;
                        _isDragging = true;
                        _dragVisual.value = (0, false);
                        widget.onDragStart(widget.tasks[index]);
                      },
                      onReorderEnd: (_) {
                        _isDragging = false;
                        _skipReorder = widget.onDragEnd();
                      },
                      onReorder: (oldIndex, newIndex) {
                        if (_skipReorder) return;
                        if (newIndex > oldIndex) newIndex--;
                        if (newIndex == oldIndex) return;
                        widget.onMove(widget.tasks[oldIndex], newIndex);
                      },
                      itemBuilder: (context, index) {
                        final task = widget.tasks[index];
                        return Padding(
                          key: ValueKey(task.id),
                          padding: const EdgeInsets.only(bottom: 9),
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            enabled: widget.canReorder,
                            child: TaskCard(task: task),
                          ),
                        );
                      },
                    ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: _composerAnimationDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: _composerAnimationDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[...previousChildren, ?currentChild],
                  ),
                  transitionBuilder: (child, animation) {
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curvedAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(curvedAnimation),
                        child: child,
                      ),
                    );
                  },
                  child: _isAddingTask
                      ? _InlineTaskComposer(
                          key: const ValueKey<String>('task-composer'),
                          controller: _taskTitleController,
                          focusNode: _taskTitleFocusNode,
                          isSubmitting: _isSubmittingTask,
                          accentColor: headerColor,
                          onSubmit: _submitTask,
                          onCancel: _closeTaskComposer,
                        )
                      : Padding(
                          key: const ValueKey<String>('add-task-button'),
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _openTaskComposer,
                              icon: const Icon(LucideIcons.plus, size: 17),
                              label: const Text('Добавить задачу'),
                              style: TextButton.styleFrom(
                                foregroundColor: headerColor,
                              ),
                            ),
                          ),
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

class _InlineTaskComposer extends StatelessWidget {
  const _InlineTaskComposer({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.accentColor,
    required this.onSubmit,
    required this.onCancel,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final Color accentColor;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey<String>('inline-task-composer'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isSubmitting,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Название задачи…',
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    backgroundColor: colors.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Добавить карточку'),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Отмена',
                  onPressed: isSubmitting ? null : onCancel,
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColumnColor(String? value) {
  final source = value?.trim();
  if (source == null || source.isEmpty) return AppColors.accent;

  var hex = source.startsWith('#') ? source.substring(1) : source;
  if (hex.length == 3) {
    hex = hex.split('').map((character) => '$character$character').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return AppColors.accent;

  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? AppColors.accent : Color(parsed);
}

enum _ColumnAction { moveLeft, moveRight, rename, archive, delete }

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'В этой колонке пока нет задач',
        style: GoogleFonts.manrope(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}

class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => Container(
        width: MediaQuery.sizeOf(context).width * 0.84,
        decoration: BoxDecoration(
          color: AppColors.subtleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _BoardMessage extends StatelessWidget {
  const _BoardMessage({
    required this.icon,
    required this.message,
    required this.action,
    this.actionLabel = 'Повторить',
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(message, style: GoogleFonts.manrope(color: AppColors.muted)),
          const SizedBox(height: 8),
          TextButton(onPressed: action, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _CreateColumnSheet extends StatefulWidget {
  const _CreateColumnSheet();

  @override
  State<_CreateColumnSheet> createState() => _CreateColumnSheetState();
}

class _CreateColumnSheetState extends State<_CreateColumnSheet> {
  final _name = TextEditingController();
  final _wip = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _wip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Новая колонка',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wip,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'WIP-лимит (необязательно)',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, (name, int.tryParse(_wip.text)));
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditColumnSheet extends StatefulWidget {
  const _EditColumnSheet({required this.column});
  final KanbanColumnModel column;

  @override
  State<_EditColumnSheet> createState() => _EditColumnSheetState();
}

class _EditColumnSheetState extends State<_EditColumnSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.column.name,
  );
  late final TextEditingController _wip = TextEditingController(
    text: widget.column.wip?.toString() ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _wip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Настройки колонки',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wip,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'WIP-лимит'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, (name, int.tryParse(_wip.text)));
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveTaskSheet extends StatefulWidget {
  const _MoveTaskSheet({required this.state, required this.task});
  final KanbanState state;
  final ProjectTaskModel task;

  @override
  State<_MoveTaskSheet> createState() => _MoveTaskSheetState();
}

class _MoveTaskSheetState extends State<_MoveTaskSheet> {
  late String _status = widget.task.status;
  int _position = 0;

  @override
  Widget build(BuildContext context) {
    final column = widget.state.columns
        .where((item) => item.statusMap == _status)
        .firstOrNull;
    final count = column == null
        ? 0
        : widget.state.tasks
              .where(
                (task) =>
                    task.status.toUpperCase() ==
                        column.statusMap.toUpperCase() &&
                    task.id != widget.task.id,
              )
              .length;
    _position = _position.clamp(0, count);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Переместить задачу',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Колонка'),
              items: <DropdownMenuItem<String>>[
                for (final item in widget.state.columns)
                  DropdownMenuItem(
                    value: item.statusMap,
                    child: Text(item.name),
                  ),
              ],
              onChanged: (value) => setState(() {
                _status = value ?? _status;
                _position = 0;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey<String>(_status),
              initialValue: _position,
              decoration: const InputDecoration(labelText: 'Позиция'),
              items: <DropdownMenuItem<int>>[
                for (var index = 0; index <= count; index++)
                  DropdownMenuItem(value: index, child: Text('${index + 1}')),
              ],
              onChanged: (value) => setState(() => _position = value ?? 0),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, (_status, _position)),
              child: const Text('Переместить'),
            ),
          ],
        ),
      ),
    );
  }
}
