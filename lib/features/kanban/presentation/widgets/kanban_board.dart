import '../../../tasks/domain/repositories/task_details_repository.dart';
import '../cubit/column_resource_cubit.dart';
import 'column_resource_sheet.dart';
import '../../../../core/auth/auth_session.dart';
import '../cubit/column_copy_cubit.dart';
import 'column_copy_sheet.dart';
import 'package:jospar/core/localization/app_translations.dart';
import '../../../projects/domain/entities/project_model.dart';
import '../../../projects/domain/entities/project_task_model.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_color_picker.dart';
import 'board_style.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/app_dialog.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../../core/widgets/app_action_menu.dart';
import 'task_card_actions.dart';
import 'task_move_sheet.dart';
import '../../domain/repositories/task_move_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/models/card_view_settings.dart';
import '../../data/storage/card_view_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tasks/domain/entities/kanban_column_model.dart';
import '../../../planner/presentation/screens/planner_screen.dart';
import 'task_card.dart';
import '../cubit/kanban_cubit.dart';
import '../cubit/kanban_state.dart';

typedef _ColumnDrop = ({String columnId, String? beforeTaskId, double markerY});

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({
    required this.project,
    this.showToolbar = true,
    super.key,
  });

  final bool showToolbar;

  final ProjectModel project;

  @override
  State<KanbanBoard> createState() => KanbanBoardState();
}

class KanbanBoardState extends State<KanbanBoard> with WidgetsBindingObserver {
  void showCardView() => _showCardView();

  void showCreateColumn() => _showCreateColumn(context);

  Timer? _cardViewRefresh;
  static const double _columnViewportFraction = 0.82;
  static const double _columnHorizontalInset = 6;
  static const _edgeHoverDelay = Duration(milliseconds: 220);
  static const _edgeRepeatDelay = Duration(milliseconds: 160);
  static const _edgeTransitionDuration = Duration(milliseconds: 180);

  final PageController _horizontalController = PageController(
    viewportFraction: _columnViewportFraction,
  );
  final _wideController = ScrollController();
  final _columnsViewport = GlobalKey();
  final _columnKeys = <String, GlobalKey<_KanbanColumnState>>{};
  bool _wideLayout = false;
  bool _geometryRefreshScheduled = false;

  String? _currentUserId;
  CardViewSettings _cardView = const CardViewSettings();
  int _viewRevision = 0;

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_refreshDragGeometry);
    _wideController.addListener(_refreshDragGeometry);
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
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(tr(context, 'Не удалось сохранить вид карточек.')),
          ),
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
                                tr(context, 'Вид карточек'),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(context, 'Изменения применяются сразу'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: tr(context, 'Закрыть'),
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
                              style: GoogleFonts.inter(
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
                        label: Text(tr(context, 'Сбросить настройки')),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onSurfaceVariant,
                          backgroundColor: colors.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: GoogleFonts.inter(
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
  final _actionTrayTarget = GlobalKey();
  final _dropActionHover = ValueNotifier<bool>(false);
  ProjectTaskModel? _draggedTask;
  _TaskDropAction? _hoveredAction;
  bool _dragCancelled = false;
  int _dragSession = 0;
  Timer? _dropActionTimer;
  _ColumnDrop? _columnDrop;
  Offset? _dragPosition;
  Timer? _edgeScrollTimer;
  int _edgeDirection = 0;
  bool _edgeScrolling = false;

  void _updateDropTarget(PointerMoveEvent event) {
    _dragPosition = event.position;
    _updateDragTargets();
  }

  Rect? _bounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _refreshDragGeometry() {
    if (_draggedTask == null || _geometryRefreshScheduled) return;
    _geometryRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryRefreshScheduled = false;
      if (mounted && _draggedTask != null) _updateDragTargets();
    });
  }

  void _updateDragTargets() {
    if (_draggedTask == null) return;
    final position = _dragPosition;
    if (position == null) return;
    final targets = {
      _TaskDropAction.archive: _archiveTarget,
      _TaskDropAction.move: _moveTarget,
      _TaskDropAction.planner: _plannerTarget,
    };
    final bounds = {
      for (final entry in targets.entries) entry.key: ?_bounds(entry.value),
    };
    _TaskDropAction? action;

    // Prefer the visible target under the pointer. Around it, use a larger
    // invisible magnetic area so the user does not have to hit the border
    // precisely while the dragged card and finger obscure the destination.
    for (final entry in bounds.entries) {
      if (entry.value.contains(position)) {
        action = entry.key;
        break;
      }
    }
    final currentBounds = bounds[_hoveredAction];
    final currentExitPadding = _hoveredAction == _TaskDropAction.planner
        ? 0.0
        : 36.0;
    if (action == null &&
        currentBounds != null &&
        currentBounds.inflate(currentExitPadding).contains(position)) {
      action = _hoveredAction;
    }
    if (action == null) {
      final magneticTargets =
          bounds.entries
              .where(
                (entry) =>
                    entry.key != _TaskDropAction.planner &&
                    entry.value.inflate(24).contains(position),
              )
              .toList()
            ..sort((a, b) {
              final aDistance = (a.value.center - position).distanceSquared;
              final bDistance = (b.value.center - position).distanceSquared;
              return aDistance.compareTo(bDistance);
            });
      action = magneticTargets.firstOrNull?.key;
    }
    if (_hoveredAction != action) {
      if (action != null) HapticFeedback.selectionClick();
      _dropActionHover.value = action != null;
      setState(() => _hoveredAction = action);
    }
    _ColumnDrop? drop;
    final viewport = _bounds(_columnsViewport);
    if (action == null && viewport?.contains(position) == true) {
      for (final key in _columnKeys.values) {
        final column = key.currentState;
        if (column == null ||
            column.widget.column.archived ||
            column.widget.column.statusMap.toUpperCase() ==
                _draggedTask!.status.toUpperCase()) {
          continue;
        }
        drop = column.dropAt(position);
        if (drop != null) break;
      }
    }
    if (_columnDrop != drop) {
      if (_columnDrop?.columnId != drop?.columnId && drop != null) {
        HapticFeedback.selectionClick();
      }
      setState(() => _columnDrop = drop);
    }
    for (final entry in _columnKeys.entries) {
      final actionTray = _bounds(_actionTrayTarget);
      entry.value.currentState?.trackIncomingDrag(
        entry.key == drop?.columnId ? position : null,
        bottom:
            actionTray != null &&
                position.dx >= actionTray.left &&
                position.dx <= actionTray.right
            ? actionTray.top - 8
            : null,
      );
    }
    if (action == null && viewport?.contains(position) == true) {
      final edge = _wideLayout ? 48.0 : 40.0;
      _setEdgeDirection(
        position.dx < viewport!.left + edge
            ? -1
            : position.dx > viewport.right - edge
            ? 1
            : 0,
      );
    } else {
      _setEdgeDirection(0);
    }
  }

  void _setEdgeDirection(int direction) {
    if (_edgeDirection == direction) return;
    _edgeDirection = direction;
    _edgeScrollTimer?.cancel();
    if (direction != 0 && !_edgeScrolling) _scheduleEdgeScroll();
  }

  void _scheduleEdgeScroll({bool repeat = false}) {
    _edgeScrollTimer?.cancel();
    final session = _dragSession;
    _edgeScrollTimer = Timer(
      repeat ? _edgeRepeatDelay : _edgeHoverDelay,
      () async {
        if (!mounted ||
            _draggedTask == null ||
            _edgeDirection == 0 ||
            session != _dragSession) {
          return;
        }
        _edgeScrolling = true;
        var advanced = false;
        try {
          if (_wideLayout && _wideController.hasClients) {
            final scroll = _wideController.position;
            final next =
                (scroll.pixels + _edgeDirection * BoardStyle.columnWidth).clamp(
                  scroll.minScrollExtent,
                  scroll.maxScrollExtent,
                );
            if (next != scroll.pixels) {
              advanced = true;
              await _wideController.animateTo(
                next,
                duration: _edgeTransitionDuration,
                curve: Curves.easeInOutCubic,
              );
            }
          } else if (!_wideLayout && _horizontalController.hasClients) {
            final columns = context.read<KanbanCubit>().state.columns;
            if (columns.isEmpty) return;
            final current = _horizontalController.page?.round() ?? 0;
            final next = (current + _edgeDirection).clamp(
              0,
              columns.length - 1,
            );
            if (next != current) {
              advanced = true;
              await _horizontalController.animateToPage(
                next,
                duration: _edgeTransitionDuration,
                curve: Curves.easeInOutCubic,
              );
            }
          }
        } finally {
          _edgeScrolling = false;
          if (mounted && _draggedTask != null && session == _dragSession) {
            _updateDragTargets();
            if (advanced &&
                _edgeDirection != 0 &&
                _edgeScrollTimer?.isActive != true) {
              _scheduleEdgeScroll(repeat: true);
            }
          }
        }
      },
    );
  }

  void _startTaskDrag(ProjectTaskModel task) {
    _dropActionTimer?.cancel();
    _dragSession++;
    _edgeScrollTimer?.cancel();
    _edgeDirection = 0;
    for (final key in _columnKeys.values) {
      key.currentState?.trackIncomingDrag(null);
    }
    _dropActionHover.value = false;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _draggedTask = task;
      _hoveredAction = null;
      _columnDrop = null;
      _dragCancelled = false;
    });
  }

  bool _endTaskDrag() {
    final task = _draggedTask;
    final action = _hoveredAction;
    final cancelled = _dragCancelled;
    final session = _dragSession;
    final drop = _columnDrop;
    final outsideSource =
        task != null &&
        !_columnKeys.values.any(
          (key) =>
              key.currentState?.widget.column.statusMap.toUpperCase() ==
                  task.status.toUpperCase() &&
              _dragPosition != null &&
              _bounds(key)?.contains(_dragPosition!) == true,
        );
    _edgeScrollTimer?.cancel();
    _edgeDirection = 0;
    _dropActionHover.value = false;
    for (final key in _columnKeys.values) {
      key.currentState?.trackIncomingDrag(null);
    }
    setState(() {
      _draggedTask = null;
      _hoveredAction = null;
      _columnDrop = null;
    });
    if (!cancelled && task != null && (action != null || drop != null)) {
      // Release the source reorder before saving or opening another route.
      _dropActionTimer = Timer(Duration.zero, () {
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
        if (action == null && drop != null) {
          final column = cubit.state.columns
              .where((column) => column.id == drop.columnId)
              .firstOrNull;
          if (column == null ||
              current.status.toUpperCase() != task.status.toUpperCase()) {
            return;
          }
          final target =
              cubit.state.tasks
                  .where(
                    (item) =>
                        item.id != task.id &&
                        item.status.toUpperCase() ==
                            column.statusMap.toUpperCase(),
                  )
                  .toList()
                ..sort((a, b) => a.order.compareTo(b.order));
          final before = target.indexWhere(
            (item) => item.id == drop.beforeTaskId,
          );
          unawaited(
            cubit.moveTask(
              current,
              column.statusMap,
              before < 0 ? target.length : before,
            ),
          );
          return;
        }
        switch (action!) {
          case _TaskDropAction.move:
            unawaited(_showMoveTask(context, current));
          case _TaskDropAction.planner:
            unawaited(showScheduleProjectTask(context, current));
          case _TaskDropAction.archive:
            unawaited(cubit.archiveTask(current));
        }
      });
    }
    return cancelled || action != null || drop != null || outsideSource;
  }

  @override
  void didUpdateWidget(covariant KanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id == widget.project.id) return;
    _dropActionTimer?.cancel();
    _edgeScrollTimer?.cancel();
    _edgeDirection = 0;
    _dragCancelled = true;
    _columnKeys.clear();
    _columnDrop = null;
    _draggedTask = null;
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
    _edgeScrollTimer?.cancel();
    _wideController.dispose();
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
            appSnackBar(
              context: context,
              tone: AppSnackBarTone.error,
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      builder: (context, state) {
        return Listener(
          onPointerDown: (event) {
            if (_draggedTask == null) _dragPosition = event.position;
          },
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
                  if (widget.showToolbar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      constraints: const BoxConstraints(
                        minHeight: BoardStyle.toolbarHeight,
                      ),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surface
                          : AppColors.of(context).canvas,
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
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.sm,
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
                      child: _TaskActionTray(
                        height:
                            64 +
                            (MediaQuery.textScalerOf(context).scale(11) - 11) *
                                5,
                        children: [
                          _TaskDropZone(
                            key: _archiveTarget,
                            label: 'Архивировать',
                            icon: LucideIcons.archive,
                            active: _hoveredAction == _TaskDropAction.archive,
                            destructive: true,
                          ),
                          _TaskDropZone(
                            key: _moveTarget,
                            label: 'Переместить',
                            icon: LucideIcons.arrowRightLeft,
                            active: _hoveredAction == _TaskDropAction.move,
                          ),
                        ],
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
                      child: _TaskActionTray(
                        key: _actionTrayTarget,
                        height:
                            64 +
                            (MediaQuery.textScalerOf(context).scale(11) - 11) *
                                5,
                        children: [
                          _TaskDropZone(
                            key: _plannerTarget,
                            label: 'В ежедневник',
                            icon: LucideIcons.calendarPlus,
                            active: _hoveredAction == _TaskDropAction.planner,
                          ),
                        ],
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
          key: _columnKeys.putIfAbsent(
            column.id,
            () => GlobalKey<_KanbanColumnState>(),
          ),
          column: column,
          canCopy:
              context.read<KanbanCubit>().supportsColumnCopy &&
              !state.columnCopyDenied,
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
              state.priorityFilter == null &&
              state.epicFilterIds.isEmpty,
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
          incomingDrop: _columnDrop?.columnId == column.id ? _columnDrop : null,
          onGeometryChanged: _refreshDragGeometry,
          onManage: (action) => _manageColumn(context, column, action),
        ),
      );
    }

    return LayoutBuilder(
      key: _columnsViewport,
      builder: (context, constraints) {
        _wideLayout = constraints.maxWidth >= 600;
        if (constraints.maxWidth >= 600) {
          return ListView.builder(
            key: PageStorageKey<String>('kanban-wide-${widget.project.id}'),
            scrollDirection: Axis.horizontal,
            controller: _wideController,
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
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<KanbanCubit, KanbanState>(
          builder: (_, state) => TaskMoveSheet(
            project: widget.project,
            state: state,
            task: task,
            repository: sl.isRegistered<TaskMoveRepository>()
                ? sl<TaskMoveRepository>()
                : null,
            onMove: (target) async {
              if (cubit.isClosed || cubit.state.projectId != projectId) {
                return false;
              }
              if (target.projectId == projectId) {
                return cubit.moveTask(
                  task,
                  target.status,
                  target.position ?? 0,
                );
              }
              return cubit.transferTask(task, target);
            },
          ),
        ),
      ),
    );
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
      case _ColumnAction.resource:
        final projectId = widget.project.id;
        final session = authSession.generation;
        final snapshot = cubit.state
            .tasksFor(column)
            .where(
              (task) =>
                  !task.archived &&
                  (_cardView.shows(CardField.completed) || !task.isDone),
            )
            .toList();
        ModalRoute<void>? resourceRoute;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) {
            resourceRoute = ModalRoute.of<void>(sheetContext);
            return BlocProvider(
              create: (_) => ColumnResourceCubit(
                tasks: snapshot,
                repository: sl.isRegistered<TaskResourceReadRepository>()
                    ? sl<TaskResourceReadRepository>()
                    : null,
                planFallback: tr(context, 'План'),
                factFallback: tr(context, 'Факт'),
                scopeChanges: cubit.stream,
                isScopeActive: () =>
                    mounted &&
                    widget.project.id == projectId &&
                    authSession.generation == session &&
                    !cubit.isClosed &&
                    cubit.state.projectId == projectId &&
                    resourceRoute?.isCurrent == true,
              )..load(),
              child: ColumnResourceSheet(columnName: column.name),
            );
          },
        );
      case _ColumnAction.copy:
        final projectId = widget.project.id;
        final viewRevision = _viewRevision;
        final session = authSession.generation;
        bool active() =>
            mounted &&
            widget.project.id == projectId &&
            _viewRevision == viewRevision &&
            authSession.generation == session &&
            !cubit.isClosed &&
            cubit.state.projectId == projectId;
        ModalRoute<String>? copyRoute;
        final copiedId = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) {
            copyRoute = ModalRoute.of<String>(sheetContext);
            return BlocProvider(
              create: (_) => ColumnCopyCubit(
                cubit,
                column,
                () => active() && copyRoute?.isCurrent == true,
              ),
              child: const ColumnCopySheet(),
            );
          },
        );
        // Finish the sheet transition before moving the page beneath it.
        await copyRoute?.completed;
        if (copiedId == null || !active() || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.success,
            content: Text(tr(context, 'Колонка скопирована')),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!active()) return;
          final index = cubit.state.columns.indexWhere(
            (item) => item.id == copiedId,
          );
          if (index < 0) return;
          if (_wideLayout && _wideController.hasClients) {
            _wideController.animateTo(
              (index * BoardStyle.columnWidth).clamp(
                0.0,
                _wideController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          } else if (_horizontalController.hasClients) {
            _horizontalController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
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
          tr(context, 'Удалить колонку?'),
          tr(
            context,
            "Колонка «{p0}» будет удалена. Это действие нельзя отменить.",
            {'p0': column.name},
          ),
          confirmLabel: 'Удалить',
          destructive: true,
        );
        if (confirmed == true) await cubit.deleteColumn(column);
    }
  }
}

enum _TaskDropAction { archive, move, planner }

class _TaskActionTray extends StatelessWidget {
  const _TaskActionTray({super.key, required this.children, this.height = 108});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 10,
                endIndent: 10,
                color: colors.outlineVariant.withValues(alpha: 0.55),
              ),
            Expanded(child: children[index]),
          ],
        ],
      ),
    );
  }
}

class _TaskDropZone extends StatelessWidget {
  const _TaskDropZone({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    this.destructive = false,
  });
  final String label;
  final IconData icon;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeColor = destructive ? colors.error : AppColors.accent;
    final foreground = active ? activeColor : colors.onSurfaceVariant;
    final icon = Icon(this.icon, size: 22, color: foreground);
    final label = Text(
      this.label,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 11,
        height: 1.15,
        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
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
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.72)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: active ? 1.06 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(height: 2), label],
          ),
        ),
      ),
    );
    return content;
  }
}

class _BoardToolbar extends StatelessWidget {
  const _BoardToolbar({required this.onAddColumn, required this.onCardView});

  final VoidCallback onAddColumn;
  final VoidCallback onCardView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        IconButton(
          key: const Key('project-epics-button'),
          tooltip: tr(context, 'Эпики'),
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
        _BoardToolbarButton(
          key: const ValueKey('card-view-button'),
          tooltip: 'Вид карточек',
          icon: LucideIcons.panelsTopLeft,
          onPressed: onCardView,
        ),
        _BoardToolbarButton(
          key: const Key('board-add-column'),
          tooltip: 'Добавить колонку',
          icon: LucideIcons.plus,
          onPressed: onAddColumn,
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
    required this.canCopy,
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
    required this.incomingDrop,
    required this.onGeometryChanged,
    required this.onManage,
  });

  final KanbanColumnModel column;
  final bool canCopy;
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
  final _ColumnDrop? incomingDrop;
  final VoidCallback onGeometryChanged;
  final ValueChanged<_ColumnAction> onManage;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn>
    with AutomaticKeepAliveClientMixin {
  static const Duration _composerAnimationDuration = Duration(
    milliseconds: 240,
  );
  static const Duration _keyboardDelay = Duration(milliseconds: 100);

  final TextEditingController _taskTitleController = TextEditingController();
  final FocusNode _taskTitleFocusNode = FocusNode();

  final _columnBounds = GlobalKey();
  final _listBounds = GlobalKey();
  final _taskBounds = <String, GlobalKey>{};
  final _scrollController = ScrollController();
  final _reorderableKey = GlobalKey<ReorderableListState>();
  Timer? _incomingScrollTimer;
  Offset? _incomingPointer;
  double? _incomingBottom;
  final _dragVisual = ValueNotifier<(double, bool)>((0, false));
  double _pointerStartX = 0;
  bool _isDragging = false;

  @override
  // Keep the source reorder alive while paging across destination columns.
  bool get wantKeepAlive => true;

  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  _ColumnDrop? dropAt(Offset position) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    if (!(origin & box.size).contains(position)) return null;
    String? before;
    var markerY = (_rect(_listBounds)?.top ?? origin.dy + 64) - origin.dy;
    for (var index = 0; index < widget.tasks.length; index++) {
      final task = widget.tasks[index];
      final key = _taskBounds[task.id];
      final rect = key == null ? null : _rect(key);
      if (rect == null) continue;
      if (position.dy < rect.center.dy) {
        before = task.id;
        markerY = rect.top - origin.dy - 4;
        break;
      }
      markerY = rect.bottom - origin.dy - 4;
      final next = index + 1;
      before = next < widget.tasks.length ? widget.tasks[next].id : null;
    }
    return (
      columnId: widget.column.id,
      beforeTaskId: before,
      markerY: markerY.clamp(
        56.0,
        (box.size.height - 12).clamp(56.0, double.infinity),
      ),
    );
  }

  void trackIncomingDrag(Offset? position, {double? bottom}) {
    _incomingPointer = position;
    _incomingBottom = bottom;
    if (position == null) {
      _incomingScrollTimer?.cancel();
      _incomingScrollTimer = null;
      return;
    }
    _incomingScrollTimer ??= Timer.periodic(const Duration(milliseconds: 40), (
      timer,
    ) {
      final pointer = _incomingPointer;
      final rect = _rect(_listBounds);
      if (pointer == null || rect == null || !_scrollController.hasClients) {
        return;
      }
      final direction = pointer.dy < rect.top + 40
          ? -1
          : pointer.dy >
                (_incomingBottom ?? rect.bottom).clamp(rect.top, rect.bottom) -
                    40
          ? 1
          : 0;
      if (direction == 0) return;
      final scroll = _scrollController.position;
      final next = (scroll.pixels + direction * 12).clamp(
        scroll.minScrollExtent,
        scroll.maxScrollExtent,
      );
      if (next != scroll.pixels) {
        _scrollController.jumpTo(next);
        widget.onGeometryChanged();
      }
    });
  }

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
    _incomingScrollTimer?.cancel();
    _scrollController.dispose();
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
        [
          AppMenuAction(
            value: _ColumnAction.moveLeft,
            label: tr(context, 'Переместить левее'),
            icon: LucideIcons.arrowLeft,
          ),
          AppMenuAction(
            value: _ColumnAction.moveRight,
            label: tr(context, 'Переместить правее'),
            icon: LucideIcons.arrowRight,
          ),
          AppMenuAction(
            value: _ColumnAction.rename,
            label: tr(context, 'Переименовать'),
            icon: LucideIcons.pencil,
            opensSubmenu: true,
          ),
          if (widget.canCopy)
            AppMenuAction(
              value: _ColumnAction.copy,
              label: tr(context, 'Копировать колонку'),
              icon: LucideIcons.copy,
            ),
        ],
        [
          AppMenuAction(
            value: _ColumnAction.resource,
            label: tr(context, 'Ресурс'),
            icon: LucideIcons.chartNoAxesCombined,
          ),
        ],
        [
          AppMenuAction(
            value: _ColumnAction.color,
            label: tr(context, 'Цвет колонки'),
            icon: LucideIcons.palette,
            opensSubmenu: true,
          ),
        ],
        [
          AppMenuAction(
            value: _ColumnAction.archive,
            label: tr(context, 'Архивировать колонку'),
            icon: LucideIcons.archive,
            muted: true,
          ),
          AppMenuAction(
            value: _ColumnAction.delete,
            label: tr(context, 'Удалить колонку'),
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
    super.build(context);
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
    final counterColor = widget.column.color == null
        ? BoardStyle.badgeBackground(context)
        : _parseColumnColor(widget.column.color).withValues(alpha: 1);
    final counterTextColor =
        ThemeData.estimateBrightnessForColor(counterColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF20212C);
    final headerColor = colors.onSurface;
    return Listener(
      onPointerDown: (event) => _pointerStartX = event.position.dx,
      onPointerMove: _trackDrag,
      onPointerCancel: (_) {
        _isDragging = false;
        _dragVisual.value = (0, false);
      },
      child: Stack(
        key: ValueKey('kanban-column-${widget.column.id}'),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              key: _columnBounds,
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: widget.incomingDrop == null
                    ? columnBackground
                    : Color.alphaBlend(
                        AppColors.accent.withValues(alpha: 0.06),
                        columnBackground,
                      ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: widget.incomingDrop == null
                      ? Colors.transparent
                      : AppColors.accent.withValues(alpha: 0.65),
                  width: 1.5,
                ),
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
                            style: GoogleFonts.inter(
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
                            color: counterColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${widget.tasks.length}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: counterTextColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: tr(context, 'Действия колонки'),
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
                    child: KeyedSubtree(
                      key: _listBounds,
                      child: widget.tasks.isEmpty
                          ? _EmptyColumn(receiving: widget.incomingDrop != null)
                          : ReorderableList(
                              key: _reorderableKey,
                              controller: _scrollController,
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
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
                                    builder: (context, child) =>
                                        Transform.translate(
                                          offset: Offset(
                                            _dragVisual.value.$1 *
                                                (_isDragging
                                                    ? 1
                                                    : animation.value),
                                            0,
                                          ),
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 120,
                                            ),
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
                                              shadowColor: AppColors.of(
                                                context,
                                              ).ink.withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                if (_skipReorder) {
                                  // The source page may be offscreen. End its local
                                  // reorder without animating back to an unpainted item.
                                  _reorderableKey.currentState?.cancelReorder();
                                }
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
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ReorderableDelayedDragStartListener(
                                    key: _taskBounds.putIfAbsent(
                                      task.id,
                                      () => GlobalKey(),
                                    ),
                                    index: index,
                                    enabled:
                                        !task.archived &&
                                        !context
                                            .watch<KanbanCubit>()
                                            .state
                                            .movingTaskIds
                                            .contains(task.id),
                                    child: TaskCard(
                                      translatedTitle: context
                                          .watch<KanbanCubit>()
                                          .state
                                          .translatedTitles[task.id],
                                      onRestoreOriginal: () => context
                                          .read<KanbanCubit>()
                                          .restoreTaskTitle(task.id),
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
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
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
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  6,
                                  10,
                                  10,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: _openTaskComposer,
                                    icon: const Icon(
                                      LucideIcons.plus,
                                      size: AppIconSizes.standard,
                                    ),
                                    label: Text(
                                      tr(context, 'Добавить карточку'),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.accent,
                                      backgroundColor:
                                          BoardStyle.badgeBackground(
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
          if (widget.incomingDrop != null)
            Positioned(
              key: ValueKey('kanban-insert-${widget.column.id}'),
              top: widget.incomingDrop!.markerY,
              left: 10,
              right: 10,
              child: const IgnorePointer(
                child: Row(
                  children: [
                    Icon(LucideIcons.circle, size: 8, color: AppColors.accent),
                    Expanded(
                      child: Divider(
                        height: 8,
                        thickness: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
              color: AppColors.of(context).ink.withValues(alpha: 0.05),
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
              decoration: InputDecoration(
                hintText: tr(context, 'Название задачи…'),
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
                      : Text(tr(context, 'Добавить карточку')),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: tr(context, 'Отмена'),
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

enum _ColumnAction {
  moveLeft,
  moveRight,
  rename,
  copy,
  resource,
  color,
  archive,
  delete,
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({this.receiving = false});

  final bool receiving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        receiving
            ? tr(context, 'Отпустите задачу здесь')
            : tr(context, 'В этой колонке пока нет задач'),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: receiving ? AppColors.accent : AppColors.of(context).muted,
          fontWeight: receiving ? FontWeight.w600 : FontWeight.w400,
        ),
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
          color: AppColors.of(context).subtleSurface,
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
          Icon(
            icon,
            color: AppColors.of(context).muted,
            size: AppIconSizes.standard,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.inter(color: AppColors.of(context).muted),
          ),
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
                tr(context, 'Новая колонка'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              AppFormField(
                label: tr(context, 'Название'),
                child: TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: tr(context, 'Введите название'),
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
                child: Text(tr(context, 'Создать')),
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
                tr(context, 'Настройки колонки'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              AppFormField(
                label: tr(context, 'Название'),
                child: TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr(context, 'Введите название'),
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
                child: Text(tr(context, 'Сохранить')),
              ),
            ],
          ),
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
          Text(
            tr(context, 'Цвет колонки'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            child: Text(tr(context, 'Сохранить')),
          ),
        ],
      ),
    ),
  );
}
