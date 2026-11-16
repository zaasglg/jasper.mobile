import '../../../../core/widgets/app_color_picker.dart';
import 'board_style.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/app_dialog.dart';
import 'dart:async';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../../core/widgets/app_action_menu.dart';
import 'task_card_actions.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/models/card_view_settings.dart';
import '../../data/storage/card_view_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import '../../../planner/presentation/screens/planner_screen.dart';
import 'task_card.dart';
import '../cubit/kanban_cubit.dart';
import '../cubit/kanban_state.dart';

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({required this.project, super.key});

  final ProjectModel project;

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> with WidgetsBindingObserver {
  Timer? _cardViewRefresh;
  static const double _columnViewportFraction = 0.82;
  static const double _columnHorizontalInset = 6;

  final PageController _horizontalController = PageController(
    viewportFraction: _columnViewportFraction,
  );

  String? _currentUserId;
  CardViewSettings _cardView = const CardViewSettings();
  int _viewRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadCardView();
    WidgetsBinding.instance.addObserver(this);
    if (sl.isRegistered<CardViewStorage>() &&
        sl<CardViewStorage>().syncEnabled) {
      _cardViewRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted &&
            TickerMode.valuesOf(context).enabled &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _loadCardView();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadCardView();
  }

  Future<void> _loadCardView() async {
    if (!sl.isRegistered<CardViewStorage>()) return;
    final revision = _viewRevision;
    try {
      final settings = await sl<CardViewStorage>().read(
        workspaceId: widget.project.workspaceId,
        projectId: widget.project.id,
      );
      final userId = await sl<CardViewStorage>().currentUserId();
      if (mounted && revision == _viewRevision) {
        setState(() {
          _cardView = settings;
          _currentUserId = userId;
        });
      }
    } catch (_) {
      // Keep defaults if saved preferences cannot be read.
    }
  }

  Future<void> _setCardView(CardViewSettings settings) async {
    _viewRevision++;
    setState(() => _cardView = settings);
    if (!sl.isRegistered<CardViewStorage>()) return;
    try {
      await sl<CardViewStorage>().save(
        settings,
        workspaceId: widget.project.workspaceId,
        projectId: widget.project.id,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить вид карточек.')),
        );
      }
    }
  }

  void _showCardView() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, updateSheet) {
          final colors = Theme.of(context).colorScheme;
          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Вид карточек',
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Изменения применяются сразу',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            fixedSize: const Size.square(36),
                          ),
                          icon: const Icon(
                            LucideIcons.x,
                            size: AppIconSizes.standard,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final field in CardField.values) ...[
                          if (field == CardField.cover ||
                              field == CardField.comments)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Divider(
                                height: 1,
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                          SwitchListTile(
                            key: ValueKey('card-field-${field.name}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            secondary: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    (_cardView.shows(field)
                                            ? AppColors.accent
                                            : colors.onSurfaceVariant)
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _cardFieldIcon(field),
                                size: AppIconSizes.standard,
                                color: _cardView.shows(field)
                                    ? AppColors.accent
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              field.label,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.onSurface,
                              ),
                            ),
                            activeTrackColor: AppColors.accent,
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: colors.surfaceContainerHighest,
                            inactiveThumbColor: colors.onSurfaceVariant,
                            trackOutlineColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            value: _cardView.shows(field),
                            onChanged: (_) {
                              _setCardView(_cardView.toggle(field));
                              updateSheet(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: SizedBox(
                      height: 48,
                      child: TextButton.icon(
                        onPressed: () {
                          _setCardView(const CardViewSettings());
                          updateSheet(() {});
                        },
                        icon: const Icon(
                          LucideIcons.rotateCcw,
                          size: AppIconSizes.standard,
                        ),
                        label: const Text('Сбросить настройки'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onSurfaceVariant,
                          backgroundColor: colors.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  final _archiveTarget = GlobalKey();
  final _moveTarget = GlobalKey();
  final _plannerTarget = GlobalKey();
  final _dropActionHover = ValueNotifier<bool>(false);
  ProjectTaskModel? _draggedTask;
  _TaskDropAction? _hoveredAction;
  bool _dragCancelled = false;
  int _dragSession = 0;
  Timer? _dropActionTimer;

  void _updateDropTarget(PointerMoveEvent event) {
    if (_draggedTask == null) return;
    _TaskDropAction? action;
    for (final entry in {
      _TaskDropAction.archive: _archiveTarget,
      _TaskDropAction.move: _moveTarget,
      _TaskDropAction.planner: _plannerTarget,
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
    if (_hoveredAction != action) {
      if (action != null) HapticFeedback.selectionClick();
      _dropActionHover.value = action != null;
      setState(() => _hoveredAction = action);
    }
  }

  void _startTaskDrag(ProjectTaskModel task) {
    _dropActionTimer?.cancel();
    _dragSession++;
    _dropActionHover.value = false;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
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
    final session = _dragSession;
    _dropActionHover.value = false;
    setState(() {
      _draggedTask = null;
      _hoveredAction = null;
    });
    if (!cancelled && task != null && action != null) {
      // Let the reorder proxy finish its drop animation before opening a sheet.
      _dropActionTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted ||
            _dragCancelled ||
            session != _dragSession ||
            widget.project.id != task.projectId) {
          return;
        }
        final cubit = context.read<KanbanCubit>();
        final current = cubit.state.tasks
            .where((item) => item.id == task.id)
            .firstOrNull;
        if (current == null ||
            current.archived ||
            cubit.state.movingTaskIds.contains(task.id)) {
          return;
        }
        switch (action) {
          case _TaskDropAction.move:
            unawaited(_showMoveTask(context, current));
          case _TaskDropAction.planner:
            unawaited(showScheduleProjectTask(context, current));
          case _TaskDropAction.archive:
            unawaited(cubit.archiveTask(current));
        }
      });
    }
    return cancelled || action != null;
  }

  @override
  void didUpdateWidget(covariant KanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id == widget.project.id) return;
    _dropActionTimer?.cancel();
    _dragCancelled = true;
    _viewRevision++;
    _cardView = const CardViewSettings();
    _currentUserId = null;
    _loadCardView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalController.hasClients) {
        _horizontalController.jumpToPage(0);
      }
    });
  }

  @override
  void dispose() {
    _dropActionHover.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _cardViewRefresh?.cancel();
    _dropActionTimer?.cancel();
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
            _dropActionTimer?.cancel();
            if (_draggedTask != null) _endTaskDrag();
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    constraints: const BoxConstraints(
                      minHeight: BoardStyle.toolbarHeight,
                    ),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surface
                        : AppColors.canvas,
                    child: IgnorePointer(
                      ignoring: _draggedTask != null,
                      child: Opacity(
                        opacity: _draggedTask == null ? 1 : 0,
                        child: _BoardToolbar(
                          onAddColumn: () => _showCreateColumn(context),
                          onCardView: _showCardView,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: BoardStyle.background(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.md,
                        ),
                        child: _boardContent(context, state),
                      ),
                    ),
                  ),
                ],
              ),
              if (_draggedTask != null) ...[
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _TaskDropZone(
                                key: _archiveTarget,
                                label: 'Архивировать',
                                icon: LucideIcons.archive,
                                active:
                                    _hoveredAction == _TaskDropAction.archive,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                    ),
                  ),
                ),
                Positioned(
                  key: const Key('kanban-planner-drop'),
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _TaskDropZone(
                        key: _plannerTarget,
                        label: 'В ежедневник',
                        icon: LucideIcons.calendarPlus,
                        subtitle: 'Дата и время после отпускания',
                        frosted: true,
                        active: _hoveredAction == _TaskDropAction.planner,
                      ),
                    ),
                  ),
                ),
              ],
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
    Widget columnBuilder(BuildContext context, int index) {
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
          onMoveTask: (task) => _showMoveTask(context, task),
          onTaskAction: (task, action) => handleTaskCardAction(
            context,
            task,
            action,
            widget.project.workspaceId,
          ),
          canReorder:
              _cardView.shows(CardField.completed) &&
              state.search.trim().isEmpty &&
              state.priorityFilter == null,
          cardView: _cardView,
          currentUserId: _currentUserId,
          tasks: state
              .tasksFor(column)
              .where(
                (task) => _cardView.shows(CardField.completed) || !task.isDone,
              )
              .toList(),
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
          dropActionHover: _dropActionHover,
          onManage: (action) => _manageColumn(context, column, action),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return ListView.builder(
            key: PageStorageKey<String>('kanban-wide-${widget.project.id}'),
            scrollDirection: Axis.horizontal,
            itemExtent: BoardStyle.columnWidth,
            itemCount: state.columns.length,
            itemBuilder: columnBuilder,
          );
        }
        return PageView.builder(
          key: PageStorageKey<String>('kanban-${widget.project.id}'),
          controller: _horizontalController,
          padEnds: false,
          itemCount: state.columns.length,
          itemBuilder: columnBuilder,
        );
      },
    );
  }

  Future<void> _showCreateColumn(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateColumnSheet(),
    );
    if (result != null && context.mounted) {
      await context.read<KanbanCubit>().createColumn(result, null);
    }
  }

  Future<void> _showMoveTask(
    BuildContext context,
    ProjectTaskModel task,
  ) async {
    final cubit = context.read<KanbanCubit>();
    final projectId = cubit.state.projectId;
    final result = await showModalBottomSheet<(String, int)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<KanbanCubit, KanbanState>(
          builder: (_, state) =>
              _MoveTaskSheet(state: state, task: task, projectId: projectId),
        ),
      ),
    );
    if (result != null &&
        context.mounted &&
        !cubit.isClosed &&
        cubit.state.projectId == projectId) {
      await cubit.moveTask(task, result.$1, result.$2);
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
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _EditColumnSheet(column: column),
        );
        if (result != null && context.mounted) {
          await cubit.updateColumn(column, result, column.wip);
        }
      case _ColumnAction.color:
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => _ColumnColorSheet(column: column),
        );
        if (result != null && context.mounted) {
          await cubit.updateColumn(
            column,
            column.name,
            column.wip,
            color: result,
          );
        }
      case _ColumnAction.archive:
        await cubit.archiveColumn(column);
      case _ColumnAction.delete:
        final confirmed = await showAppConfirmation(
          context,
          'Удалить колонку?',
          'Колонка «${column.name}» будет удалена. Это действие нельзя отменить.',
          confirmLabel: 'Удалить',
          destructive: true,
        );
        if (confirmed == true) await cubit.deleteColumn(column);
    }
  }
}

enum _TaskDropAction { archive, move, planner }

class _TaskDropZone extends StatelessWidget {
  const _TaskDropZone({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    this.subtitle,
    this.frosted = false,
  });
  final String label;
  final IconData icon;
  final bool active;
  final String? subtitle;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = active ? AppColors.accent : colors.onSurface;
    final icon = Icon(this.icon, size: 24, color: foreground);
    final label = Text(
      this.label,
      maxLines: 2,
      textAlign: frosted ? TextAlign.start : TextAlign.center,
      style: GoogleFonts.manrope(
        fontSize: frosted ? 15 : 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    );
    final content = Semantics(
      container: true,
      selected: active,
      label: this.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active
              ? Color.alphaBlend(
                  AppColors.accent.withValues(alpha: 0.12),
                  colors.surface.withValues(alpha: frosted ? 0.94 : 1),
                )
              : colors.surface.withValues(alpha: frosted ? 0.88 : 0.98),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.accent
                : colors.outlineVariant.withValues(alpha: 0.8),
            width: active ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: active ? 0.12 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: frosted
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: icon,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label,
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [icon, const SizedBox(height: 8), label],
              ),
      ),
    );
    if (!frosted) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: content,
      ),
    );
  }
}

class _BoardToolbar extends StatefulWidget {
  const _BoardToolbar({required this.onAddColumn, required this.onCardView});

  final VoidCallback onAddColumn;
  final VoidCallback onCardView;

  @override
  State<_BoardToolbar> createState() => _BoardToolbarState();
}

class _BoardToolbarState extends State<_BoardToolbar> {
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (_searching)
          Expanded(
            child: TextFormField(
              key: const Key('board-search-field'),
              initialValue: context.read<KanbanCubit>().state.search,
              autofocus: true,
              onChanged: context.read<KanbanCubit>().setSearch,
              decoration: const InputDecoration(
                hintText: 'Поиск на доске',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
            ),
          )
        else ...[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                selected: true,
                label: 'Доска проекта',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.smMd,
                    vertical: AppSpacing.smMd,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.columns2,
                        color: AppColors.accent,
                        size: BoardStyle.iconSize,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'Доска',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title(
                            context,
                          )?.copyWith(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('project-epics-button'),
            tooltip: 'Эпики',
            onPressed: () => context.push(
              '/projects/${context.read<KanbanCubit>().state.projectId}/epics',
              extra: context.read<KanbanCubit>(),
            ),
            icon: Badge(
              isLabelVisible: context
                  .watch<KanbanCubit>()
                  .state
                  .epicFilterIds
                  .isNotEmpty,
              label: Text(
                '${context.watch<KanbanCubit>().state.epicFilterIds.length}',
              ),
              child: const Icon(LucideIcons.layers, size: BoardStyle.iconSize),
            ),
          ),
        ],
        IconButton(
          key: const Key('board-search-toggle'),
          tooltip: _searching ? 'Закрыть поиск' : 'Поиск на доске',
          onPressed: () {
            if (_searching) context.read<KanbanCubit>().setSearch('');
            setState(() => _searching = !_searching);
          },
          icon: Icon(
            _searching ? LucideIcons.x : LucideIcons.search,
            color: colors.onSurface,
            size: BoardStyle.iconSize,
          ),
        ),
        _BoardToolbarButton(
          key: const ValueKey('card-view-button'),
          tooltip: 'Вид карточек',
          icon: LucideIcons.panelsTopLeft,
          onPressed: widget.onCardView,
        ),
        _BoardToolbarButton(
          key: const Key('board-add-column'),
          tooltip: 'Добавить колонку',
          icon: LucideIcons.plus,
          onPressed: widget.onAddColumn,
        ),
      ],
    );
  }
}

class _BoardToolbarButton extends StatefulWidget {
  const _BoardToolbarButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  State<_BoardToolbarButton> createState() => _BoardToolbarButtonState();
}

class _BoardToolbarButtonState extends State<_BoardToolbarButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.96 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: IconButton(
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: BoardStyle.iconSize),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(48),
            minimumSize: const Size.square(48),
            maximumSize: const Size.square(48),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const CircleBorder(),
            foregroundColor: colors.onSurface,
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    super.key,
    required this.column,
    required this.canReorder,
    required this.cardView,
    this.currentUserId,
    required this.onMoveTask,
    required this.onTaskAction,
    required this.tasks,
    required this.onAddTask,
    required this.onMove,
    required this.onDragStart,
    required this.onDragEnd,
    required this.dropActionHover,
    required this.onManage,
  });

  final KanbanColumnModel column;
  final bool canReorder;
  final CardViewSettings cardView;
  final String? currentUserId;
  final ValueChanged<ProjectTaskModel> onMoveTask;
  final void Function(ProjectTaskModel, TaskCardAction) onTaskAction;
  final List<ProjectTaskModel> tasks;
  final Future<bool> Function(String title) onAddTask;
  final void Function(ProjectTaskModel task, int position) onMove;
  final ValueChanged<ProjectTaskModel> onDragStart;
  final bool Function() onDragEnd;
  final ValueNotifier<bool> dropActionHover;
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
    final created = await widget.onAddTask(title);
    if (!mounted) return;
    if (!created) {
      setState(() => _isSubmittingTask = false);
      _taskTitleFocusNode.requestFocus();
      return;
    }

    _taskTitleController.clear();
    _taskTitleFocusNode.unfocus();
    setState(() {
      _isAddingTask = false;
      _isSubmittingTask = false;
    });
  }

  Future<void> _showColumnMenu() async {
    final action = await showAppActionMenu<_ColumnAction>(
      context,
      title: widget.column.name,
      eyebrow: 'Действия колонки',
      groups: [
        const [
          AppMenuAction(
            value: _ColumnAction.moveLeft,
            label: 'Переместить левее',
            icon: LucideIcons.arrowLeft,
          ),
          AppMenuAction(
            value: _ColumnAction.moveRight,
            label: 'Переместить правее',
            icon: LucideIcons.arrowRight,
          ),
          AppMenuAction(
            value: _ColumnAction.rename,
            label: 'Переименовать',
            icon: LucideIcons.pencil,
            opensSubmenu: true,
          ),
        ],
        const [
          AppMenuAction(
            value: _ColumnAction.color,
            label: 'Цвет колонки',
            icon: LucideIcons.palette,
            opensSubmenu: true,
          ),
        ],
        const [
          AppMenuAction(
            value: _ColumnAction.archive,
            label: 'Архивировать',
            icon: LucideIcons.archive,
            muted: true,
          ),
          AppMenuAction(
            value: _ColumnAction.delete,
            label: 'Удалить',
            icon: LucideIcons.trash2,
            destructive: true,
          ),
        ],
      ],
    );

    if (action != null && mounted) widget.onManage(action);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final baseBackground = BoardStyle.listBackground(context);
    final columnBackground = widget.column.color == null
        ? baseBackground
        : Color.alphaBlend(
            _parseColumnColor(widget.column.color).withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.22
                  : 0.18,
            ),
            baseBackground,
          );
    final headerColor = colors.onSurface;
    return Listener(
      onPointerDown: (event) => _pointerStartX = event.position.dx,
      onPointerMove: _trackDrag,
      onPointerCancel: (_) {
        _isDragging = false;
        _dragVisual.value = (0, false);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          key: _columnBounds,
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: columnBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.column.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: BoardStyle.columnTitleSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
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
                        color: BoardStyle.badgeBackground(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${widget.tasks.length}',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: headerColor,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Действия колонки',
                      onPressed: _showColumnMenu,
                      icon: Icon(
                        LucideIcons.ellipsis,
                        size: AppIconSizes.standard,
                        color: headerColor,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: widget.tasks.isEmpty
                    ? const _EmptyColumn()
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        buildDefaultDragHandles: false,
                        autoScrollerVelocityScalar: 45,
                        itemCount: widget.tasks.length,
                        proxyDecorator: (child, index, animation) =>
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                animation,
                                _dragVisual,
                                widget.dropActionHover,
                              ]),
                              child: child,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(
                                  _dragVisual.value.$1 *
                                      (_isDragging ? 1 : animation.value),
                                  0,
                                ),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 120),
                                  opacity:
                                      widget.dropActionHover.value &&
                                          _isDragging
                                      ? 0
                                      : _dragVisual.value.$2
                                      ? 0.65
                                      : 1,
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
                        onReorderItem: (oldIndex, newIndex) {
                          if (_skipReorder || !widget.canReorder) return;
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
                              enabled:
                                  !task.archived &&
                                  !context
                                      .watch<KanbanCubit>()
                                      .state
                                      .movingTaskIds
                                      .contains(task.id),
                              child: TaskCard(
                                boardStyle: true,
                                task: task,
                                cardView: widget.cardView,
                                currentUserId: widget.currentUserId,
                                onAction: (action) =>
                                    widget.onTaskAction(task, action),
                                onMove:
                                    context
                                        .watch<KanbanCubit>()
                                        .state
                                        .movingTaskIds
                                        .contains(task.id)
                                    ? null
                                    : () => widget.onMoveTask(task),
                                isUpdating: context
                                    .watch<KanbanCubit>()
                                    .state
                                    .movingTaskIds
                                    .contains(task.id),
                                onToggleCompleted:
                                    context
                                        .watch<KanbanCubit>()
                                        .state
                                        .movingTaskIds
                                        .contains(task.id)
                                    ? null
                                    : () => context
                                          .read<KanbanCubit>()
                                          .toggleCompleted(task),
                              ),
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
                                icon: const Icon(
                                  LucideIcons.plus,
                                  size: AppIconSizes.standard,
                                ),
                                label: const Text('Добавить карточку'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  backgroundColor: BoardStyle.badgeBackground(
                                    context,
                                  ).withValues(alpha: 0.65),
                                  minimumSize: const Size.fromHeight(
                                    AppSpacing.touchTarget,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.smMd,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
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
                  icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
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

enum _ColumnAction { moveLeft, moveRight, rename, color, archive, delete }

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'В этой колонке пока нет задач',
        textAlign: TextAlign.center,
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
          Icon(icon, color: AppColors.muted, size: AppIconSizes.standard),
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSurface(
      child: SafeArea(
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
              AppFormField(
                label: 'Название',
                child: TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Введите название',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppFormButton(
                onPressed: () {
                  final name = _name.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(context, name);
                  }
                },
                child: const Text('Создать'),
              ),
            ],
          ),
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSurface(
      child: SafeArea(
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
              AppFormField(
                label: 'Название',
                child: TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Введите название',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppFormButton(
                onPressed: () {
                  final name = _name.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(context, name);
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveTaskSheet extends StatefulWidget {
  const _MoveTaskSheet({
    required this.state,
    required this.task,
    required this.projectId,
  });
  final String projectId;
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
    final task = widget.state.projectId == widget.projectId
        ? widget.state.tasks
              .where((item) => item.id == widget.task.id)
              .firstOrNull
        : null;
    final column = widget.state.columns
        .where(
          (item) =>
              !item.archived &&
              item.statusMap.toUpperCase() == _status.toUpperCase(),
        )
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
      child: SingleChildScrollView(
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
            Text(
              widget.task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'В какую колонку?',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.35,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.state.columns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = widget.state.columns[index];
                  final selected =
                      item.statusMap.toUpperCase() == _status.toUpperCase();
                  final current =
                      item.statusMap.toUpperCase() ==
                      task?.status.toUpperCase();
                  return Material(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      key: ValueKey('move-to-${item.id}'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        LucideIcons.columns3,
                        color: _parseColumnColor(item.color),
                        size: AppIconSizes.standard,
                      ),
                      title: Text(item.name),
                      subtitle: current ? const Text('Текущая колонка') : null,
                      trailing: Icon(
                        selected ? LucideIcons.circleCheck : LucideIcons.circle,
                        color: selected
                            ? AppColors.accent
                            : Theme.of(context).colorScheme.outline,
                        size: AppIconSizes.standard,
                      ),
                      onTap: () => setState(() {
                        _status = item.statusMap;
                        _position = 0;
                      }),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            AppFormField(
              label: 'Позиция',
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                key: ValueKey((_status, count, _position)),
                initialValue: _position,
                decoration: const InputDecoration(hintText: 'Позиция'),
                items: <DropdownMenuItem<int>>[
                  for (var index = 0; index <= count; index++)
                    DropdownMenuItem(value: index, child: Text('${index + 1}')),
                ],
                onChanged: (value) => setState(() => _position = value ?? 0),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('confirm-task-move'),
              onPressed:
                  task == null ||
                      column == null ||
                      widget.state.movingTaskIds.contains(widget.task.id)
                  ? null
                  : () => Navigator.pop(context, (column.statusMap, _position)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.arrowRightLeft,
                    size: AppIconSizes.standard,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      task == null
                          ? 'Задача больше недоступна'
                          : column == null
                          ? 'Выберите колонку'
                          : 'Перенести в «${column.name}»',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _cardFieldIcon(CardField field) => switch (field) {
  CardField.completed => LucideIcons.circleCheck,
  CardField.cover => LucideIcons.image,
  CardField.id => LucideIcons.hash,
  CardField.assignees => LucideIcons.users,
  CardField.dates => LucideIcons.calendarDays,
  CardField.epics => LucideIcons.layers,
  CardField.labels => LucideIcons.tag,
  CardField.personalLabels => LucideIcons.lockKeyhole,
  CardField.comments => LucideIcons.messageCircle,
  CardField.timing => LucideIcons.clock,
  CardField.checklists => LucideIcons.listChecks,
  CardField.resources => LucideIcons.chartNoAxesCombined,
  CardField.files => LucideIcons.paperclip,
};

class _ColumnColorSheet extends StatefulWidget {
  const _ColumnColorSheet({required this.column});
  final KanbanColumnModel column;

  @override
  State<_ColumnColorSheet> createState() => _ColumnColorSheetState();
}

class _ColumnColorSheetState extends State<_ColumnColorSheet> {
  late String _color = widget.column.color ?? '#94A3B8';

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Цвет колонки', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            widget.column.name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          AppColorPicker(
            value: _color,
            extraColors: const [Color(0xFF94A3B8)],
            onChanged: (value) => setState(() => _color = value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save_column_color'),
            onPressed: () => Navigator.pop(context, _color),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}
