import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/planner_week_order_cubit.dart';
import 'planner_week_reorderable_tasks.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/planner_item_model.dart';
import '../../domain/utils/planner_dates.dart';

class PlannerWeekView extends StatefulWidget {
  const PlannerWeekView({
    super.key,
    required this.selectedDate,
    required this.items,
    required this.busyIds,
    required this.saving,
    required this.onEdit,
    required this.onToggle,
    this.onCreate,
    this.orderCubit,
    this.onRemove,
  });
  final PlannerWeekOrderCubit? orderCubit;
  final ValueChanged<PlannerItemModel>? onRemove;
  final DateTime selectedDate;
  final List<PlannerItemModel> items;
  final Set<String> busyIds;
  final bool saving;
  final ValueChanged<PlannerItemModel> onEdit, onToggle;
  final Future<bool> Function(DateTime day, String title, TimeOfDay? time)?
  onCreate;
  @override
  State<PlannerWeekView> createState() => _PlannerWeekViewState();
}

class _PlannerWeekViewState extends State<PlannerWeekView> {
  bool _grid = true;
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  Timer? _autoScroll;
  Offset? _pointer;
  ValueChanged<Offset>? _rehit;

  void _startDrag(ValueChanged<Offset> rehit) {
    _stopDrag();
    _rehit = rehit;
    _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final pointer = _pointer;
      final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
      if (pointer == null ||
          box == null ||
          !box.hasSize ||
          !_scroll.hasClients) {
        return;
      }
      final local = box.globalToLocal(pointer);
      if (local.dx < 0 || local.dx > box.size.width) return;
      const edge = 64.0;
      final delta = local.dy < edge
          ? -((edge - local.dy) / edge).clamp(0, 1) * 14
          : local.dy > box.size.height - edge
          ? ((local.dy - box.size.height + edge) / edge).clamp(0, 1) * 14
          : 0.0;
      final next = (_scroll.offset + delta).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      if (next != _scroll.offset) {
        _scroll.jumpTo(next);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pointer != null) _rehit?.call(_pointer!);
        });
      }
    });
  }

  void _stopDrag() {
    _autoScroll?.cancel();
    _autoScroll = null;
    _pointer = null;
    _rehit = null;
  }

  @override
  void dispose() {
    _stopDrag();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.orderCubit == null
      ? _buildWeek(context, null)
      : BlocBuilder<PlannerWeekOrderCubit, PlannerWeekOrderState>(
          bloc: widget.orderCubit,
          builder: (context, order) => _buildWeek(context, order),
        );

  Widget _buildWeek(BuildContext context, PlannerWeekOrderState? order) {
    final date = widget.selectedDate;
    final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    return SizedBox.expand(
      key: _viewport,
      child: ListView(
        controller: _scroll,
        key: const Key('planner-week-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final grid in [true, false])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    key: ValueKey(
                      grid ? 'planner-week-grid' : 'planner-week-list',
                    ),
                    tooltip: grid
                        ? tr(context, 'Плитки')
                        : tr(context, 'Список'),
                    isSelected: _grid == grid,
                    onPressed: () => setState(() => _grid = grid),
                    style: IconButton.styleFrom(
                      backgroundColor: _grid == grid
                          ? AppColors.of(context).subtleSurface
                          : Colors.transparent,
                      foregroundColor: AppColors.of(context).ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      grid ? LucideIcons.layoutGrid : LucideIcons.list,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          if (order?.error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, order!.error!),
                    style: TextStyle(
                      color: AppColors.of(context).error,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!order.ready)
                  TextButton(
                    onPressed: widget.orderCubit!.initialize,
                    child: Text(tr(context, 'Повторить')),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (context) {
                final day = DateTime(monday.year, monday.month, monday.day + i);
                final items = PlannerWeekOrderCubit.ordered(
                  day,
                  widget.items,
                  order?.orders ?? const {},
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _WeekDayCard(
                    key: ValueKey(plannerDayString(day)),
                    day: day,
                    items: items,
                    grid: _grid,
                    busyIds: widget.busyIds,
                    saving: widget.saving,
                    onEdit: widget.onEdit,
                    onToggle: widget.onToggle,
                    onCreate: widget.onCreate,
                    onRemove: widget.onRemove,
                    orderScope: order?.scope,
                    reorderEnabled:
                        order?.ready == true &&
                        order?.saving != true &&
                        !widget.saving &&
                        widget.busyIds.isEmpty,
                    onReorder: (ids) =>
                        widget.orderCubit?.reorder(day, ids, widget.items),
                    onDragStart: _startDrag,
                    onDragPosition: (pointer) => _pointer = pointer,
                    onDragEnd: _stopDrag,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WeekDayCard extends StatefulWidget {
  const _WeekDayCard({
    super.key,
    required this.day,
    required this.items,
    required this.grid,
    required this.busyIds,
    required this.saving,
    required this.onEdit,
    required this.onToggle,
    required this.onCreate,
    required this.onRemove,
    required this.orderScope,
    required this.reorderEnabled,
    required this.onReorder,
    required this.onDragStart,
    required this.onDragPosition,
    required this.onDragEnd,
  });
  final String? orderScope;
  final bool reorderEnabled;
  final ValueChanged<List<String>> onReorder;
  final ValueChanged<ValueChanged<Offset>> onDragStart;
  final ValueChanged<Offset> onDragPosition;
  final VoidCallback onDragEnd;
  final ValueChanged<PlannerItemModel>? onRemove;
  final DateTime day;
  final List<PlannerItemModel> items;
  final bool grid, saving;
  final Set<String> busyIds;
  final ValueChanged<PlannerItemModel> onEdit, onToggle;
  final Future<bool> Function(DateTime, String, TimeOfDay?)? onCreate;
  @override
  State<_WeekDayCard> createState() => _WeekDayCardState();
}

class _WeekDayCardState extends State<_WeekDayCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  static const _months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  static const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  final _input = TextEditingController();
  final _focus = FocusNode();
  TimeOfDay? _time;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_changed);
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _input.text.trim();
    if (title.isEmpty || _saving || widget.saving || widget.onCreate == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    bool success;
    try {
      success = await widget.onCreate!(widget.day, title, _time);
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (success) {
        _input.clear();
      } else {
        _error = 'Не удалось добавить. Повторите попытку.';
      }
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final enabled = !_saving && !widget.saving && widget.onCreate != null;
    final id = plannerDayString(widget.day);
    return Container(
      key: ValueKey('planner-week-day-$id'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${widget.day.day}',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.of(context).ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_months[widget.day.month - 1]}  ${_days[widget.day.weekday - 1]}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.of(context).badgeSurface,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${widget.items.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.of(context).border,
            ),
          ),
          if (widget.items.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    widget.grid &&
                        constraints.maxWidth >= 260 &&
                        MediaQuery.textScalerOf(context).scale(13) <= 17
                    ? 2
                    : 1;
                return PlannerWeekReorderableTasks(
                  items: widget.items,
                  columns: columns,
                  spacing: widget.grid ? 8 : 0,
                  cardHeight: widget.grid
                      ? 19 +
                            MediaQuery.textScalerOf(context).scale(13) * 2.8 +
                            MediaQuery.textScalerOf(context).scale(11) * 1.4
                      : 20 +
                            (MediaQuery.textScalerOf(context).scale(14) * 1.4)
                                .ceilToDouble() +
                            (MediaQuery.textScalerOf(context).scale(12) * 1.4)
                                .ceilToDouble(),
                  enabled: widget.reorderEnabled,
                  scope: widget.orderScope,
                  onReorder: widget.onReorder,
                  onDragStart: widget.onDragStart,
                  onDragPosition: widget.onDragPosition,
                  onDragEnd: widget.onDragEnd,
                  cardBuilder: (item, dragBody, feedback) =>
                      _task(item, dragBody: dragBody, feedback: feedback),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).subtleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focus.hasFocus
                    ? AppColors.of(context).accent.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final large = MediaQuery.textScalerOf(context).scale(13) > 17;
                final field = TextField(
                  key: ValueKey('planner-week-input-$id'),
                  controller: _input,
                  focusNode: _focus,
                  enabled: enabled,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.of(context).ink,
                  ),
                  decoration: InputDecoration(
                    hintText: tr(context, 'Добавить задачу…'),
                    hintStyle: TextStyle(
                      color: AppColors.of(context).muted,
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                );
                final actions = Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      key: ValueKey('planner-week-time-$id'),
                      onPressed: !enabled
                          ? null
                          : () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime:
                                    _time ??
                                    const TimeOfDay(hour: 12, minute: 30),
                                builder: (context, child) => MediaQuery(
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                ),
                              );
                              if (mounted && time != null) {
                                setState(() => _time = time);
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.of(context).muted,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: Text(
                        _time == null
                            ? '12:30'
                            : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                        semanticsLabel: _time == null
                            ? tr(context, 'Указать время, необязательно')
                            : null,
                        style: TextStyle(
                          fontSize: 12,
                          color: _time == null
                              ? AppColors.of(
                                  context,
                                ).muted.withValues(alpha: 0.7)
                              : AppColors.of(context).muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (_time != null)
                      IconButton(
                        tooltip: tr(context, 'Весь день'),
                        onPressed: enabled
                            ? () => setState(() => _time = null)
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 40,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 14),
                      ),
                    TextButton(
                      key: ValueKey('planner-week-submit-$id'),
                      onPressed: enabled && _input.text.trim().isNotEmpty
                          ? _submit
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.of(context).accent,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enter', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                );
                return large
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          Align(
                            alignment: Alignment.centerRight,
                            child: actions,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            LucideIcons.plus,
                            size: 18,
                            color: AppColors.of(context).muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: field),
                          actions,
                        ],
                      );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(context, _error!),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.of(context).error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _task(
    PlannerItemModel item, {
    required Widget Function(Widget) dragBody,
    bool feedback = false,
  }) {
    final busy = widget.busyIds.contains(item.id) || widget.saving || feedback;
    final displayId = item.task?.displayId.trim() ?? '';
    final identifier = item.taskId == null
        ? ''
        : displayId.isNotEmpty
        ? displayId
        : item.taskId!.trim();
    final metadata = [
      if (identifier.isNotEmpty) identifier,
      if (item.scheduledAt != null && !item.allDay)
        plannerClock(plannerLocal(item.scheduledAt!)),
    ].join(' · ');
    return Material(
      key: feedback ? null : ValueKey('planner-week-item-${item.id}'),
      color: widget.grid
          ? AppColors.of(context).subtleSurface
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: !widget.grid && !feedback && item.id != widget.items.last.id
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.of(context).border,
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!item.external)
              SizedBox(
                width: widget.grid ? 36 : 44,
                child: Checkbox(
                  key: feedback
                      ? null
                      : ValueKey('planner-week-check-${item.id}'),
                  value: item.completed,
                  activeColor: AppColors.of(context).accent,
                  shape: widget.grid
                      ? null
                      : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                  side: widget.grid
                      ? null
                      : BorderSide(
                          color: item.completed
                              ? AppColors.of(context).accent
                              : AppColors.of(context).muted,
                          width: 1.4,
                        ),
                  onChanged: busy ? null : (_) => widget.onToggle(item),
                  semanticLabel: tr(
                    context,
                    item.completed ? 'Вернуть в план' : 'Отметить выполненной',
                  ),
                ),
              ),
            Expanded(
              child: dragBody(
                InkWell(
                  key: feedback
                      ? null
                      : ValueKey('planner-week-open-${item.id}'),
                  onTap: busy ? null : () => widget.onEdit(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (item.inboxTaskId != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              LucideIcons.inbox,
                              size: widget.grid ? 16 : 18,
                              color: AppColors.of(context).muted,
                              semanticLabel: tr(context, 'Инбокс'),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                maxLines: widget.grid ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: widget.grid ? 13 : 14,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: item.completed
                                      ? AppColors.of(context).muted
                                      : AppColors.of(context).ink,
                                  decoration: item.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (metadata.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    metadata,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: widget.grid ? 11 : 12,
                                      height: 1.4,
                                      color: AppColors.of(context).muted,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!item.external && widget.onRemove != null)
              SizedBox(
                width: widget.grid ? 32 : 44,
                child: IconButton(
                  key: feedback
                      ? null
                      : ValueKey('planner-week-remove-${item.id}'),
                  tooltip: tr(context, 'Убрать из ежедневника'),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    LucideIcons.x,
                    size: 16,
                    color: AppColors.of(context).muted,
                  ),
                  onPressed: busy ? null : () => widget.onRemove!(item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
