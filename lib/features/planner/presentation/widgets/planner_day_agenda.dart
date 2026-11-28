import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:jospar/core/localization/app_translations.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/planner_item_model.dart';
import '../../domain/utils/planner_dates.dart';
import '../../domain/utils/planner_day_scale.dart';
import 'planner_task_symbol.dart';

/// The web day's adaptive timeline with task symbols centered on its rail.
class PlannerDayAgenda extends StatefulWidget {
  const PlannerDayAgenda({
    required this.selectedDate,
    required this.now,
    required this.items,
    required this.busyIds,
    required this.onCreate,
    required this.onEdit,
    required this.onToggle,
    this.onMenu,
    this.onSchedule,
    this.onResize,
    this.enableUntimedDrag = false,
    this.hasUntimedPlans = false,
    super.key,
  });
  final DateTime selectedDate, now;
  final List<PlannerItemModel> items;
  final Set<String> busyIds;
  final VoidCallback onCreate;
  final ValueChanged<PlannerItemModel> onEdit, onToggle;
  final ValueChanged<PlannerItemModel>? onMenu;
  final bool hasUntimedPlans;
  final bool enableUntimedDrag;
  final Future<bool> Function(PlannerItemModel item, int durationMinutes)?
  onResize;
  final void Function(PlannerItemModel item, DateTime time)? onSchedule;

  @override
  State<PlannerDayAgenda> createState() => _PlannerDayAgendaState();
}

class _PlannerDayAgendaState extends State<PlannerDayAgenda> {
  final _contentKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  Timer? _edgeTimer;
  Offset? _pointer;
  PlannerItemModel? _dragged;
  PlannerDayScale? _scale;
  int? _minute;
  Offset? _timedDragOrigin;
  double _timedDragAnchorY = 0, _timedDragScroll = 0;

  bool _timedDragMoved(Offset position) =>
      _timedDragOrigin == null ||
      (position.dy - _timedDragOrigin!.dy).abs() > 4 ||
      (_scroll.hasClients && (_scroll.offset - _timedDragScroll).abs() > 1);

  void _startTimedDrag(Offset origin, double anchorY) {
    _timedDragOrigin = origin;
    _timedDragAnchorY = anchorY;
    _timedDragScroll = _scroll.hasClients ? _scroll.offset : 0;
  }

  void _endTimedDrag() {
    _timedDragOrigin = null;
    _timedDragAnchorY = 0;
    _clearDrag();
  }

  PlannerItemModel? _resizing;
  PlannerDayScale? _resizeScale;
  double _resizePointerY = 0,
      _resizeOriginalEndY = 0,
      _resizeEndY = 0,
      _resizeScroll = 0;
  int _resizeDuration = 0;
  bool _committingResize = false;
  Timer? _resizeTimer;
  Offset? _resizePosition;

  bool _canResize(PlannerItemModel item) =>
      !item.external &&
      !item.archived &&
      widget.onResize != null &&
      !widget.busyIds.contains(item.id) &&
      _minutes(item) <= 1425;

  void _startResize(PlannerItemModel item, DragStartDetails details) {
    if (!_canResize(item) || _resizing != null) return;
    _clearDrag();
    setState(() {
      _resizing = item;
      _resizeScale = _scale;
      _resizePointerY = details.globalPosition.dy;
      _resizePosition = details.globalPosition;
      _resizeScroll = _scroll.hasClients ? _scroll.offset : 0;
      _resizeOriginalEndY = _scale!.toY(
        _minutes(item) + item.durationMinutes,
        clamp: false,
      );
      _resizeEndY = _resizeOriginalEndY;
      _resizeDuration = item.durationMinutes;
    });
    _resizeTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted ||
          !_scroll.hasClients ||
          _resizePosition == null ||
          _committingResize) {
        return;
      }
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final y = box.globalToLocal(_resizePosition!).dy;
      final step = y < 48
          ? -8.0
          : y > box.size.height - 48
          ? 8.0
          : 0.0;
      final offset = (_scroll.offset + step).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if (offset != _scroll.offset) {
        _scroll.jumpTo(offset);
        _applyResizePosition();
      }
    });
  }

  void _updateResize(DragUpdateDetails details) {
    _resizePosition = details.globalPosition;
    _applyResizePosition();
  }

  void _applyResizePosition() {
    final item = _resizing;
    if (item == null || _committingResize) return;
    final scale = _resizeScale!;
    final scrollDelta =
        (_scroll.hasClients ? _scroll.offset : 0) - _resizeScroll;
    final endY =
        (_resizeOriginalEndY +
                _resizePosition!.dy -
                _resizePointerY +
                scrollDelta)
            .clamp(
              scale.toY(_minutes(item) + 15, clamp: false),
              scale.toY(1440, clamp: false),
            );
    final maxDuration = 1440 - _minutes(item).round();
    setState(() {
      _resizeEndY = endY;
      _resizeDuration =
          (((scale.toMinutes(endY, clamp: false) - _minutes(item)) / 15)
                      .round() *
                  15)
              .clamp(15, maxDuration);
    });
  }

  void _cancelResize() {
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _resizePosition = null;
    if (!mounted) return;
    setState(() {
      _resizing = null;
      _resizeScale = null;
      _committingResize = false;
    });
  }

  Future<void> _finishResize() async {
    final item = _resizing;
    final save = widget.onResize;
    if (item == null || _committingResize) return;
    if (save == null || _resizeDuration == item.durationMinutes) {
      _cancelResize();
      return;
    }
    _resizeTimer?.cancel();
    setState(() => _committingResize = true);
    try {
      await save(item, _resizeDuration);
    } finally {
      _cancelResize();
    }
  }

  bool _canSchedule(PlannerItemModel item) =>
      widget.onSchedule != null &&
      _resizing == null &&
      !item.external &&
      !item.archived &&
      !widget.busyIds.contains(item.id) &&
      widget.items.any(
        (current) =>
            current.id == item.id &&
            !current.archived &&
            current.scheduledAt == item.scheduledAt &&
            current.durationMinutes == item.durationMinutes &&
            (current.day == null ||
                samePlannerDay(current.day!, widget.selectedDate)),
      ) &&
      (item.scheduledAt != null
          ? samePlannerDay(plannerLocal(item.scheduledAt!), widget.selectedDate)
          : item.plannedDate == null ||
                samePlannerDay(item.plannedDate!, widget.selectedDate));

  int _minuteAt(Offset position, PlannerItemModel item) {
    if (item.scheduledAt != null && !_timedDragMoved(position)) {
      final local = plannerLocal(item.scheduledAt!);
      return local.hour * 60 + local.minute;
    }
    final box = _contentKey.currentContext!.findRenderObject()! as RenderBox;
    final minute =
        (_scale!.toMinutes(box.globalToLocal(position).dy) / 15).round() * 15;
    return minute.clamp(0, 1440 - item.durationMinutes.clamp(15, 1440));
  }

  void _move(DragTargetDetails<PlannerItemModel> details) {
    if (!_canSchedule(details.data)) return;
    _pointer = details.offset;
    _dragged = details.data;
    final minute = _minuteAt(details.offset, details.data);
    if (_minute != minute) setState(() => _minute = minute);
    _edgeTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients || _pointer == null || !mounted) return;
      final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final y = box.globalToLocal(_pointer! + Offset(0, _timedDragAnchorY)).dy;
      final step = y < 48
          ? -8.0
          : y > box.size.height - 48
          ? 8.0
          : 0.0;
      final offset = (_scroll.offset + step).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if (offset != _scroll.offset) {
        _scroll.jumpTo(offset);
        final minute = _minuteAt(_pointer!, _dragged!);
        if (_minute != minute) setState(() => _minute = minute);
      }
    });
  }

  void _clearDrag() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    _pointer = null;
    _dragged = null;
    if (mounted && _minute != null) setState(() => _minute = null);
  }

  @override
  void dispose() {
    _edgeTimer?.cancel();
    _resizeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  double _minutes(PlannerItemModel item) {
    final time = plannerLocal(item.scheduledAt!);
    return (time.hour * 60 + time.minute).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sorted =
        widget.items
            .where(
              (item) =>
                  !item.archived &&
                  !item.allDay &&
                  item.scheduledAt != null &&
                  samePlannerDay(
                    plannerLocal(item.scheduledAt!),
                    widget.selectedDate,
                  ),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    return LayoutBuilder(
      builder: (context, box) {
        final intervals = [
          for (final item in sorted)
            (
              start: _minutes(item),
              end: math.min(
                1440.0,
                _minutes(item) + item.durationMinutes.clamp(15, 1440),
              ),
            ),
        ];
        final scale =
            _resizeScale ??
            PlannerDayScale(intervals, math.max(120, box.maxHeight));
        double endY(PlannerItemModel item) => _resizing?.id == item.id
            ? _resizeEndY
            : scale.toY(
                math.min(
                  1440,
                  _minutes(item) + item.durationMinutes.clamp(15, 1440),
                ),
              );
        final contentHeight = _resizing == null
            ? scale.height
            : math.max(scale.height, _resizeEndY + 32);
        _scale = scale;
        // Only tasks in the same overlapping time group share columns.
        final ends = <DateTime>[];
        final lanes = <String, int>{};
        final columnCounts = <String, int>{};
        final group = <PlannerItemModel>[];
        DateTime? groupEnd;
        void finishGroup() {
          for (final item in group) {
            columnCounts[item.id] = math.max(1, ends.length);
          }
          group.clear();
          ends.clear();
          groupEnd = null;
        }

        for (final item in sorted) {
          if (groupEnd != null && !item.scheduledAt!.isBefore(groupEnd!)) {
            finishGroup();
          }
          var lane = ends.indexWhere((end) => !end.isAfter(item.scheduledAt!));
          if (lane < 0) {
            lane = ends.length;
            ends.add(item.scheduledAt!);
          }
          ends[lane] = item.scheduledAt!.add(
            Duration(minutes: item.durationMinutes.clamp(15, 1440)),
          );
          lanes[item.id] = lane;
          group.add(item);
          if (groupEnd == null || ends[lane].isAfter(groupEnd!)) {
            groupEnd = ends[lane];
          }
        }
        finishGroup();
        double columnWidth(PlannerItemModel item) =>
            math.max(1.0, (box.maxWidth - 44) / columnCounts[item.id]!);
        return DragTarget<PlannerItemModel>(
          onWillAcceptWithDetails: (details) => _canSchedule(details.data),
          onMove: _move,
          onLeave: (_) => _clearDrag(),
          onAcceptWithDetails: (details) {
            if (!_canSchedule(details.data)) {
              _clearDrag();
              return;
            }
            final item = details.data;
            final minute = _minuteAt(details.offset, item);
            final time = plannerInstant(
              widget.selectedDate,
              minute ~/ 60,
              minute % 60,
            );
            final unchanged =
                item.scheduledAt != null &&
                (!_timedDragMoved(details.offset) ||
                    item.scheduledAt!.isAtSameMomentAs(time));
            _clearDrag();
            if (!unchanged) widget.onSchedule!(item, time);
          },
          builder: (context, candidates, rejected) => ColoredBox(
            key: _viewportKey,
            color: colors.surface,
            child: SingleChildScrollView(
              controller: _scroll,
              key: const Key('planner-day-agenda'),
              physics: _resizing == null
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: SizedBox(
                key: _contentKey,
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 65,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: ColoredBox(
                        color: colors.outlineVariant.withValues(alpha: .6),
                      ),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('planner-timeline-create'),
                        behavior: HitTestBehavior.translucent,
                        onTap: widget.onCreate,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    for (final hour in const [6, 9, 12, 15, 18]) ...[
                      Positioned(
                        left: 6,
                        top: scale
                            .toY(hour * 60.0)
                            .clamp(2.0, math.max(2.0, scale.height - 18)),
                        child: Text(
                          '$hour:00',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 61,
                        width: 9,
                        top: scale.toY(hour * 60.0) + 7,
                        child: Divider(height: 1, color: colors.outlineVariant),
                      ),
                    ],
                    if (samePlannerDay(widget.selectedDate, widget.now))
                      Positioned(
                        key: const Key('planner-now-marker'),
                        left: 4,
                        right: 12,
                        top: scale
                            .toY(
                              (widget.now.hour * 60 + widget.now.minute)
                                  .toDouble(),
                            )
                            .clamp(0.0, math.max(0.0, scale.height - 18)),
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  plannerClock(widget.now),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: AppColors.accent.withValues(
                                    alpha: .35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_minute != null && candidates.isNotEmpty)
                      Positioned(
                        key: const Key('planner-drop-time'),
                        left: 4,
                        right: 12,
                        top: scale
                            .toY(_minute!.toDouble())
                            .clamp(0.0, math.max(0.0, scale.height - 28)),
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${(_minute! ~/ 60).toString().padLeft(2, '0')}:${(_minute! % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: AppColors.accent,
                                  thickness: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final item in sorted)
                      Positioned(
                        key: ValueKey('planner-agenda-${item.id}'),
                        top: scale.toY(_minutes(item)) + 2,
                        left: 44 + lanes[item.id]! * columnWidth(item),
                        width: columnWidth(item),
                        height: math.max(
                          28,
                          endY(item) - scale.toY(_minutes(item)) - 4,
                        ),
                        child: _DayTask(
                          item: item,
                          resizeEnabled:
                              _canResize(item) &&
                              (_resizing == null || _resizing!.id == item.id),
                          resizing: _resizing?.id == item.id,
                          onResizeStart: (details) =>
                              _startResize(item, details),
                          onResizeUpdate: _updateResize,
                          onResizeEnd: _finishResize,
                          onResizeCancel: _cancelResize,
                          dragEnabled: _resizing == null,
                          onDragOrigin: _startTimedDrag,
                          onDragEnd: _endTimedDrag,
                          draggable:
                              widget.enableUntimedDrag &&
                              !item.external &&
                              !widget.busyIds.contains(item.id),
                          busy: widget.busyIds.contains(item.id),
                          onEdit: () => widget.onEdit(item),
                          onToggle: () => widget.onToggle(item),
                          onMenu: item.external || widget.onMenu == null
                              ? null
                              : () => widget.onMenu!(item),
                        ),
                      ),
                    if (_resizing != null)
                      Positioned(
                        left: 100,
                        right: 44,
                        top: math.max(0, _resizeEndY - 50),
                        child: IgnorePointer(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              key: const Key('planner-resize-preview'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tr(context, '{p0} мин', {
                                  'p0': _resizeDuration,
                                }),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
          ),
        );
      },
    );
  }
}

class _DayTask extends StatelessWidget {
  const _DayTask({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    this.onMenu,
    this.draggable = false,
    this.resizeEnabled = false,
    this.resizing = false,
    this.dragEnabled = true,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
    this.onDragOrigin,
    this.onDragEnd,
  });
  final void Function(Offset origin, double anchorY)? onDragOrigin;
  final VoidCallback? onDragEnd;
  final bool draggable, resizeEnabled, resizing, dragEnabled;
  final GestureDragStartCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;
  final VoidCallback? onResizeCancel;
  final Future<void> Function()? onResizeEnd;
  final PlannerItemModel item;
  final bool busy;
  final VoidCallback onEdit, onToggle;
  final VoidCallback? onMenu;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final symbol = plannerTaskSymbol(context, item);
    final displayId = item.task?.displayId.trim() ?? '';
    final identifier = item.taskId == null
        ? ''
        : displayId.isNotEmpty
        ? displayId
        : item.taskId!.trim();
    final time = plannerClock(plannerLocal(item.scheduledAt!));
    final title = Material(
      color: colors.surface,
      child: InkWell(
        key: ValueKey('planner-open-${item.id}'),
        onTap: busy ? null : onEdit,
        onLongPress: busy || draggable ? null : onMenu,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScaler = MediaQuery.textScalerOf(context);
              final headingHeight = textScaler.scale(12) * 1.2;
              final titleStyle = GoogleFonts.inter(
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: item.completed
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
                decoration: item.completed ? TextDecoration.lineThrough : null,
              );
              const gap = 3.0;
              final maxLines = math.max(
                1,
                ((constraints.maxHeight - headingHeight - gap) /
                        (textScaler.scale(16) * 1.25))
                    .floor(),
              );
              final painter = TextPainter(
                text: TextSpan(text: item.title, style: titleStyle),
                textDirection: Directionality.of(context),
                textScaler: textScaler,
                maxLines: maxLines,
                ellipsis: '…',
              )..layout(maxWidth: constraints.maxWidth);
              final contentTop = math.max(
                0.0,
                (constraints.maxHeight - headingHeight - gap - painter.height) /
                    2,
              );
              painter.dispose();
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: contentTop,
                    left: 0,
                    right: 0,
                    child: Text(
                      identifier.isEmpty ? time : '$identifier - $time',
                      key: ValueKey('planner-time-${item.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Positioned(
                    top: contentTop + headingHeight + gap,
                    left: 0,
                    right: 0,
                    child: Text(
                      item.title,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 42,
          child: Material(
            color: item.external ? const Color(0xFF6886A5) : symbol.color,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey(
                item.external
                    ? 'planner-event-${item.id}'
                    : 'planner-complete-${item.id}',
              ),
              onTap: busy
                  ? null
                  : item.external
                  ? onEdit
                  : onToggle,
              child: Semantics(
                button: true,
                label: item.external
                    ? tr(context, 'Событие Google Календаря')
                    : item.completed
                    ? tr(context, 'Вернуть в план')
                    : tr(context, 'Отметить выполненной'),
                child: Center(
                  child: item.external
                      ? const Icon(
                          Icons.event_outlined,
                          size: 20,
                          color: Colors.white,
                        )
                      : PlannerTaskSymbol(
                          item: item,
                          busy: busy,
                          size: 21,
                          onFilledBackground: true,
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: title),
        if (onMenu != null)
          Center(
            child: SizedBox(
              width: 32,
              height: 44,
              child: IconButton(
                key: ValueKey('planner-item-menu-${item.id}'),
                tooltip: tr(context, 'Действия записи'),
                padding: EdgeInsets.zero,
                icon: Icon(
                  LucideIcons.ellipsis,
                  size: 17,
                  color: colors.onSurfaceVariant,
                ),
                onPressed: busy ? null : onMenu,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: row),
        if (resizeEnabled)
          Positioned(
            left: 0,
            right: 0,
            bottom: -10,
            child: Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: Semantics(
                  label: tr(context, 'Изменить длительность'),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      gestureSettings: const DeviceGestureSettings(
                        touchSlop: 4,
                      ),
                    ),
                    child: Listener(
                      onPointerCancel: (_) => onResizeCancel?.call(),
                      child: GestureDetector(
                        key: ValueKey('planner-resize-${item.id}'),
                        behavior: HitTestBehavior.opaque,
                        dragStartBehavior: DragStartBehavior.down,
                        onVerticalDragStart: onResizeStart,
                        onVerticalDragUpdate: onResizeUpdate,
                        onVerticalDragEnd: (_) => onResizeEnd?.call(),
                        onVerticalDragCancel: onResizeCancel,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 4,
                            decoration: BoxDecoration(
                              color: resizing
                                  ? AppColors.accent
                                  : colors.onSurfaceVariant.withValues(
                                      alpha: .5,
                                    ),
                              borderRadius: BorderRadius.circular(2),
                            ),
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
    );
    return !draggable
        ? content
        : LongPressDraggable<PlannerItemModel>(
            key: ValueKey('planner-timed-drag-${item.id}'),
            data: item,
            maxSimultaneousDrags: dragEnabled ? 1 : 0,
            dragAnchorStrategy: (_, context, position) {
              final box = context.findRenderObject()! as RenderBox;
              // Keep the task's start under its original grab offset.
              final top = box.localToGlobal(Offset.zero).dy - 2;
              final anchorY = position.dy - top;
              onDragOrigin?.call(Offset(position.dx, top), anchorY);
              return Offset(0, anchorY);
            },
            onDragEnd: (_) => onDragEnd?.call(),
            feedback: Material(
              elevation: 6,
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 220,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.onSurface),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: .35, child: content),
            child: content,
          );
  }
}
