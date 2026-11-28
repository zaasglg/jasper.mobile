import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/planner_item_model.dart';

typedef WeekTaskBuilder =
    Widget Function(
      PlannerItemModel item,
      Widget Function(Widget body) dragBody,
      bool feedback,
    );

/// A single day's row-major drop region. The cards keep their original layout
/// during tracking, so cancellation is lossless and the drag source stays alive.
class PlannerWeekReorderableTasks extends StatefulWidget {
  const PlannerWeekReorderableTasks({
    super.key,
    required this.items,
    required this.columns,
    required this.cardHeight,
    this.spacing = 8,
    required this.enabled,
    required this.cardBuilder,
    required this.scope,
    required this.onReorder,
    required this.onDragStart,
    required this.onDragPosition,
    required this.onDragEnd,
  });
  final List<PlannerItemModel> items;
  final int columns;
  final double cardHeight, spacing;
  final bool enabled;
  final String? scope;
  final WeekTaskBuilder cardBuilder;
  final ValueChanged<List<String>> onReorder;
  final ValueChanged<ValueChanged<Offset>> onDragStart;
  final ValueChanged<Offset> onDragPosition;
  final VoidCallback onDragEnd;
  @override
  State<PlannerWeekReorderableTasks> createState() =>
      _PlannerWeekReorderableTasksState();
}

class _WeekTaskDrag {
  const _WeekTaskDrag(this.token, this.id);
  final Object token;
  final String id;
}

class _PlannerWeekReorderableTasksState
    extends State<PlannerWeekReorderableTasks> {
  final _region = GlobalKey();
  final _boxes = <String, GlobalKey>{};
  Object _token = Object();
  String? _dragging;
  Offset? _pointer;
  int? _insertion, _target;
  bool _after = false;
  bool get _enabled => widget.enabled && widget.items.length > 1;

  @override
  void didUpdateWidget(PlannerWeekReorderableTasks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        !listEquals(oldWidget.items, widget.items) ||
        !widget.enabled ||
        oldWidget.columns != widget.columns) {
      _clear(rebuild: false);
    }
  }

  @override
  void dispose() {
    if (_dragging != null) widget.onDragEnd();
    super.dispose();
  }

  void _clear({bool rebuild = true}) {
    final wasDragging = _dragging != null;
    _token = Object();
    _dragging = null;
    _insertion = _target = null;
    _pointer = null;
    if (wasDragging) widget.onDragEnd();
    if (rebuild && mounted) setState(() {});
  }

  void _locate(Offset pointer) {
    if (_dragging == null || !mounted) return;
    _pointer = pointer;
    final region = _region.currentContext?.findRenderObject() as RenderBox?;
    int? target;
    bool after = false;
    var closest = double.infinity;
    if (region != null &&
        region.hasSize &&
        (Offset.zero & region.size).contains(region.globalToLocal(pointer))) {
      for (var i = 0; i < widget.items.length; i++) {
        final box =
            _boxes[widget.items[i].id]?.currentContext?.findRenderObject()
                as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final local = box.globalToLocal(pointer);
        final distance = (local - box.size.center(Offset.zero)).distanceSquared;
        if (distance < closest) {
          closest = distance;
          target = i;
          after = widget.columns > 1
              ? local.dx > box.size.width / 2
              : local.dy > box.size.height / 2;
        }
      }
    }
    final insertion = target == null ? null : target + (after ? 1 : 0);
    if (_insertion != insertion || _target != target || _after != after) {
      setState(() {
        _insertion = insertion;
        _target = target;
        _after = after;
      });
    }
  }

  void _drop(_WeekTaskDrag data) {
    if (data.token != _token || data.id != _dragging || !_enabled) return;
    if (_pointer != null) _locate(_pointer!);
    final insertion = _insertion;
    if (insertion == null) {
      _clear();
      return;
    }
    final ids = widget.items.map((e) => e.id).toList();
    final from = ids.indexOf(data.id);
    if (from < 0) {
      _clear();
      return;
    }
    ids.removeAt(from);
    ids.insert(
      (insertion > from ? insertion - 1 : insertion).clamp(0, ids.length),
      data.id,
    );
    final changed = !listEquals(ids, widget.items.map((e) => e.id).toList());
    _clear();
    if (changed) widget.onReorder(ids);
  }

  void _accessibleMove(int from, int to) {
    if (!_enabled) return;
    final ids = widget.items.map((e) => e.id).toList();
    ids.insert(to, ids.removeAt(from));
    widget.onReorder(ids);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width =
          (constraints.maxWidth - (widget.columns - 1) * widget.spacing) /
          widget.columns;
      return DragTarget<_WeekTaskDrag>(
        onWillAcceptWithDetails: (details) =>
            _enabled && details.data.token == _token,
        onMove: (_) {
          if (_pointer != null) _locate(_pointer!);
        },
        onLeave: (_) {
          if (mounted) {
            setState(() {
              _insertion = _target = null;
            });
          }
        },
        onAcceptWithDetails: (details) => _drop(details.data),
        builder: (context, candidates, rejected) => Wrap(
          key: _region,
          spacing: widget.spacing,
          runSpacing: widget.spacing,
          children: [
            for (final (index, item) in widget.items.indexed)
              SizedBox(
                key: _boxes.putIfAbsent(item.id, GlobalKey.new),
                width: width,
                height: widget.cardHeight,
                child: Semantics(
                  key: ValueKey('planner-week-semantics-${item.id}'),
                  container: true,
                  explicitChildNodes: true,
                  label: item.displayTitle,
                  customSemanticsActions: !_enabled
                      ? null
                      : {
                          if (index > 0)
                            CustomSemanticsAction(
                              label: tr(context, 'Переместить выше'),
                            ): () =>
                                _accessibleMove(index, index - 1),
                          if (index < widget.items.length - 1)
                            CustomSemanticsAction(
                              label: tr(context, 'Переместить ниже'),
                            ): () =>
                                _accessibleMove(index, index + 1),
                        },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: _dragging == item.id ? .25 : 1,
                          child: widget.cardBuilder(
                            item,
                            (body) => Listener(
                              onPointerCancel: (_) => _clear(),
                              child: LongPressDraggable<_WeekTaskDrag>(
                                data: _WeekTaskDrag(_token, item.id),
                                maxSimultaneousDrags:
                                    _enabled && _dragging == null ? 1 : 0,
                                dragAnchorStrategy: (_, context, position) {
                                  final box =
                                      _boxes[item.id]?.currentContext
                                              ?.findRenderObject()
                                          as RenderBox?;
                                  return box?.globalToLocal(position) ??
                                      Offset.zero;
                                },
                                hapticFeedbackOnStart: true,
                                feedback: IgnorePointer(
                                  child: SizedBox(
                                    width: width,
                                    height: widget.cardHeight,
                                    child: Material(
                                      elevation: 5,
                                      borderRadius: BorderRadius.circular(12),
                                      child: widget.cardBuilder(
                                        item,
                                        (body) => body,
                                        true,
                                      ),
                                    ),
                                  ),
                                ),
                                onDragStarted: () {
                                  setState(() => _dragging = item.id);
                                  widget.onDragStart(_locate);
                                },
                                onDragUpdate: (details) {
                                  _locate(details.globalPosition);
                                  widget.onDragPosition(details.globalPosition);
                                },
                                onDragEnd: (_) => _clear(),
                                onDraggableCanceled: (_, _) => _clear(),
                                child: body,
                              ),
                            ),
                            false,
                          ),
                        ),
                      ),
                      if (_target == index && _dragging != null)
                        Positioned(
                          left: widget.columns > 1 ? (_after ? null : -3) : 0,
                          right: widget.columns > 1 ? (_after ? -3 : null) : 0,
                          top: widget.columns > 1 ? 0 : (_after ? null : -3),
                          bottom: widget.columns > 1 ? 0 : (_after ? -3 : null),
                          width: widget.columns > 1 ? 3 : null,
                          height: widget.columns > 1 ? null : 3,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: const Key('planner-week-insertion'),
                              decoration: BoxDecoration(
                                color: AppColors.of(context).accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
