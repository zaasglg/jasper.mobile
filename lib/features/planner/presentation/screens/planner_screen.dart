import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/screens/main_shell.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../../../projects/presentation/cubit/projects_cubit.dart';
import '../../../projects/presentation/cubit/projects_state.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../projects/domain/repositories/project_task_repository.dart';
import '../../../inbox/domain/repositories/inbox_repository.dart';
import '../../../inbox/data/models/inbox_task_model.dart';
import '../../data/models/planner_item_model.dart';
import '../../domain/utils/planner_dates.dart';
import '../cubit/planner_cubit.dart';
import '../cubit/planner_state.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

enum _View { day, week, month }

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selectedDate = plannerDate(plannerNow());
  _View _view = _View.day;
  List<ProjectTaskModel> _tasks = [];
  List<ProjectModel> _projects = [];
  String _taskScope = '';
  String? _taskError;
  int _taskRevision = 0;
  Timer? _clock;
  PlannerCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= context.read<PlannerCubit?>();
    final workspace = context.read<WorkspaceCubit?>()?.state;
    if (workspace is WorkspaceLoaded) {
      _cubit?.configure(workspace.selected?.id ?? '');
    }
    final projects = context.read<ProjectsCubit?>()?.state;
    if (projects != null) _loadTasks(projects);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _taskRevision++;
    super.dispose();
  }

  List<ProjectModel> _flatten(List<ProjectModel> projects) => [
    for (final project in projects) ...[project, ..._flatten(project.children)],
  ];
  Future<void> _loadTasks(ProjectsState state, {bool force = false}) async {
    _projects = _flatten(state.projects);
    final ids = _projects.map((e) => e.id).toList();
    final scope = '${state.workspaceId}:${ids.join(',')}';
    if ((!force && scope == _taskScope) ||
        !sl.isRegistered<ProjectTaskRepository>()) {
      return;
    }
    _taskScope = scope;
    final revision = ++_taskRevision;
    setState(() {
      _tasks = [];
      _taskError = null;
    });
    if (ids.isEmpty) return;
    try {
      final tasks = await sl<ProjectTaskRepository>().getTasksForProjectIds(
        ids,
      );
      if (mounted && revision == _taskRevision) {
        setState(() => _tasks = tasks.where((e) => !e.archived).toList());
      }
    } catch (_) {
      if (mounted && revision == _taskRevision) {
        setState(() => _taskError = 'Не удалось загрузить сроки задач.');
      }
    }
  }

  Future<void> _refresh() async {
    final projects = context.read<ProjectsCubit?>()?.state;
    await Future.wait([
      if (_cubit != null) _cubit!.refresh(),
      if (projects != null) _loadTasks(projects, force: true),
    ]);
  }

  void _selectDate(DateTime date) =>
      setState(() => _selectedDate = plannerDate(date));
  void _move(int direction) {
    _selectDate(
      _view == _View.month
          ? DateTime(_selectedDate.year, _selectedDate.month + direction, 1)
          : DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day + direction * (_view == _View.week ? 7 : 1),
            ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (date != null && mounted) _selectDate(date);
  }

  Future<void> _edit({PlannerItemModel? item, int? hour}) async {
    final cubit = _cubit;
    if (cubit == null || cubit.state.workspaceId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _PlannerEditor(
          item: item,
          initialDate: _selectedDate,
          hour: hour ?? 9,
          tasks: _tasks,
          projects: _projects,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget screen = _cubit == null
        ? _scaffold(const PlannerState())
        : BlocConsumer<PlannerCubit, PlannerState>(
            listenWhen: (a, b) => a.actionRevision != b.actionRevision,
            listener: (context, state) {
              if (state.actionError != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.actionError!)));
              }
            },
            builder: (_, state) => _scaffold(state),
          );
    if (context.read<ProjectsCubit?>() != null) {
      screen = BlocListener<ProjectsCubit, ProjectsState>(
        listenWhen: (a, b) =>
            a.workspaceId != b.workspaceId || a.projects != b.projects,
        listener: (_, state) => _loadTasks(state),
        child: screen,
      );
    }
    if (context.read<WorkspaceCubit?>() != null) {
      screen = BlocListener<WorkspaceCubit, WorkspaceState>(
        listener: (_, state) {
          if (state is WorkspaceLoaded) {
            _cubit?.configure(state.selected?.id ?? '');
            _taskRevision++;
            setState(() {
              _tasks = [];
              _taskError = null;
            });
          }
        },
        child: screen,
      );
    }
    return screen;
  }

  Widget _scaffold(PlannerState state) {
    final items = state.items.where((e) => !e.archived).toList();
    final due = _tasks
        .where(
          (e) =>
              e.end != null &&
              samePlannerDay(plannerLocal(e.end!), _selectedDate),
        )
        .toList();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Открыть меню',
          onPressed: MainShell.openDrawer,
          icon: const Icon(Icons.menu_rounded),
        ),
        title: Text(
          'Ежедневник',
          style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            key: const Key('planner-today'),
            tooltip: 'Выбрать дату',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
        ],
      ),
      floatingActionButton: state.workspaceId.isEmpty
          ? null
          : FloatingActionButton.small(
              key: const Key('planner-add'),
              tooltip: 'Добавить задачу',
              onPressed: state.isSaving ? null : () => _edit(),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_View>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      segments: const [
                        ButtonSegment(value: _View.day, label: Text('День')),
                        ButtonSegment(value: _View.week, label: Text('Неделя')),
                        ButtonSegment(value: _View.month, label: Text('Месяц')),
                      ],
                      selected: {_view},
                      onSelectionChanged: (value) =>
                          setState(() => _view = value.single),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('planner-date-picker'),
                      onTap: _pickDate,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('planner-previous-day'),
                    tooltip: 'Назад',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(plannerNow()),
                    child: const Text('Сегодня'),
                  ),
                  IconButton(
                    key: const Key('planner-next-day'),
                    tooltip: 'Вперёд',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            if (state.status == PlannerStatus.loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
              ),
            if (state.error != null || _taskError != null)
              MaterialBanner(
                content: Text(state.error ?? _taskError!),
                actions: [
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            if (_view == _View.week) _weekStrip(items),
            Expanded(
              child: _view == _View.month
                  ? _monthGrid(items)
                  : GestureDetector(
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() > 180) _move(velocity < 0 ? 1 : -1);
                      },
                      child: Column(
                        children: [
                          SizedBox(
                            height: 44,
                            child: Center(
                              child: Text(
                                _heading(_selectedDate),
                                key: const Key('planner-selected-date'),
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          _dueLane(due),
                          if (items.any((e) => e.scheduledAt == null))
                            _unscheduled(
                              items
                                  .where((e) => e.scheduledAt == null)
                                  .toList(),
                            ),
                          Expanded(
                            child: _DayTimeline(
                              key: ValueKey(_selectedDate),
                              selectedDate: _selectedDate,
                              items: items
                                  .where(
                                    (e) =>
                                        e.scheduledAt != null &&
                                        samePlannerDay(
                                          plannerLocal(e.scheduledAt!),
                                          _selectedDate,
                                        ),
                                  )
                                  .toList(),
                              busyIds: state.busyIds,
                              onCreate: (hour) => _edit(hour: hour),
                              onEdit: (item) => _edit(item: item),
                              onToggle: (item) => _cubit?.toggle(item),
                              onMove: (item, hour) => _cubit?.save(
                                item: item,
                                title: item.title,
                                scheduledAt: plannerInstant(
                                  _selectedDate,
                                  hour,
                                  0,
                                ),
                                durationMinutes: item.durationMinutes,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueLane(List<ProjectTaskModel> due) => Container(
    height: due.isEmpty
        ? 44
        : (due.length * 44.0 + 8).clamp(44, 120).toDouble(),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 57,
          child: Center(
            child: Text(
              'GMT+5',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: due.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _taskError != null
                        ? 'Сроки задач недоступны'
                        : 'Нет задач со сроком',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final task in due)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            task.isDone
                                ? Icons.check_circle
                                : Icons.flag_outlined,
                            color: task.isDone
                                ? AppColors.accent
                                : AppColors.muted,
                            size: 18,
                          ),
                          title: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () async {
                            await context.push(
                              '/tasks/${task.id}',
                              extra: task,
                            );
                            if (mounted) _refresh();
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _unscheduled(List<PlannerItemModel> items) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        const Center(
          child: Text(
            'Без времени  ',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              label: Text(item.title, overflow: TextOverflow.ellipsis),
              onPressed: () => _edit(item: item),
            ),
          ),
      ],
    ),
  );

  Widget _weekStrip(List<PlannerItemModel> items) {
    final monday = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day - _selectedDate.weekday + 1,
    );
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          for (var index = 0; index < 7; index++)
            Expanded(
              child: Builder(
                builder: (_) {
                  final day = DateTime(
                    monday.year,
                    monday.month,
                    monday.day + index,
                  );
                  final selected = samePlannerDay(day, _selectedDate);
                  final count = items
                      .where(
                        (e) =>
                            e.scheduledAt != null &&
                            samePlannerDay(plannerLocal(e.scheduledAt!), day),
                      )
                      .length;
                  return InkWell(
                    onTap: () => _selectDate(day),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _shortDays[index],
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : null,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          count > 0 ? '$count' : '',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthGrid(List<PlannerItemModel> items) {
    final first = DateTime(_selectedDate.year, _selectedDate.month);
    final start = DateTime(first.year, first.month, 2 - first.weekday);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              for (final name in _shortDays)
                Expanded(
                  child: Center(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) => GridView.builder(
              itemCount: 42,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: (box.maxHeight / 6).clamp(68, 110).toDouble(),
              ),
              itemBuilder: (_, index) {
                final day = DateTime(
                  start.year,
                  start.month,
                  start.day + index,
                );
                final events = items
                    .where(
                      (e) =>
                          e.scheduledAt != null &&
                          samePlannerDay(plannerLocal(e.scheduledAt!), day),
                    )
                    .toList();
                final deadlineCount = _tasks
                    .where(
                      (e) =>
                          e.end != null &&
                          samePlannerDay(plannerLocal(e.end!), day),
                    )
                    .length;
                return InkWell(
                  key: ValueKey('planner-month-${day.toIso8601String()}'),
                  onTap: () => setState(() {
                    _selectedDate = day;
                    _view = _View.day;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                      color: samePlannerDay(day, plannerNow())
                          ? AppColors.accent.withValues(alpha: 0.06)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: day.month == _selectedDate.month
                                ? null
                                : AppColors.muted,
                          ),
                        ),
                        for (final item in events.take(2))
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.accent,
                            ),
                          ),
                        if (events.length > 2)
                          Text(
                            '+${events.length - 2}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                        if (deadlineCount > 0)
                          Text(
                            'Сроки: $deadlineCount',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DayTimeline extends StatefulWidget {
  const _DayTimeline({
    super.key,
    required this.selectedDate,
    required this.items,
    required this.busyIds,
    required this.onCreate,
    required this.onEdit,
    required this.onToggle,
    required this.onMove,
  });
  final DateTime selectedDate;
  final List<PlannerItemModel> items;
  final Set<String> busyIds;
  final ValueChanged<int> onCreate;
  final ValueChanged<PlannerItemModel> onEdit, onToggle;
  final void Function(PlannerItemModel item, int hour) onMove;
  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  static const hourHeight = 64.0;
  late final ScrollController _scroll;
  @override
  void initState() {
    super.initState();
    final dates = widget.items.map((e) => plannerLocal(e.scheduledAt!)).toList()
      ..sort();
    final hour = dates.isEmpty ? 8 : dates.first.hour;
    _scroll = ScrollController(initialScrollOffset: hour * hourHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.items]
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    // Assign overlapping items to separate lanes, preserving the full hit area.
    final lanes = <String, int>{};
    final ends = <DateTime>[];
    for (final item in sorted) {
      var lane = ends.indexWhere((end) => !end.isAfter(item.scheduledAt!));
      if (lane < 0) {
        lane = ends.length;
        ends.add(item.scheduledAt!);
      }
      ends[lane] = item.scheduledAt!.add(
        Duration(minutes: item.durationMinutes.clamp(15, 1440)),
      );
      lanes[item.id] = lane;
    }
    final laneCount = ends.isEmpty ? 1 : ends.length;
    final now = plannerNow();
    return SingleChildScrollView(
      controller: _scroll,
      child: SizedBox(
        height: 24 * hourHeight,
        child: LayoutBuilder(
          builder: (_, box) => Stack(
            children: [
              for (var hour = 0; hour < 24; hour++)
                Positioned(
                  top: hour * hourHeight,
                  left: 0,
                  right: 0,
                  height: hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 57,
                        child: Center(
                          heightFactor: 1.3,
                          child: Text(
                            hour.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: DragTarget<PlannerItemModel>(
                          onAcceptWithDetails: (details) =>
                              widget.onMove(details.data, hour),
                          builder: (context, candidates, rejected) => InkWell(
                            key: ValueKey('planner-hour-$hour'),
                            onTap: () => widget.onCreate(hour),
                            child: Container(
                              decoration: BoxDecoration(
                                color: candidates.isEmpty
                                    ? null
                                    : AppColors.accent.withValues(alpha: 0.08),
                                border: Border(
                                  left: BorderSide(color: AppColors.border),
                                  top: BorderSide(color: AppColors.border),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final item in sorted)
                Builder(
                  builder: (_) {
                    final time = plannerLocal(item.scheduledAt!);
                    final top =
                        ((time.hour + time.minute / 60) * hourHeight + 2)
                            .clamp(0.0, 24 * hourHeight - 30)
                            .toDouble();
                    final width = (box.maxWidth - 65) / laneCount;
                    final height = (item.durationMinutes / 60 * hourHeight - 4)
                        .clamp(28, 24 * hourHeight - top)
                        .toDouble();
                    return Positioned(
                      top: top,
                      left: 61 + lanes[item.id]! * width,
                      width: width - 4,
                      height: height,
                      child: LongPressDraggable<PlannerItemModel>(
                        data: item,
                        maxSimultaneousDrags: widget.busyIds.contains(item.id)
                            ? 0
                            : 1,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: const SizedBox.shrink(),
                        child: Material(
                          color: AppColors.accent.withValues(
                            alpha: item.completed ? 0.07 : 0.13,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            onTap: () => widget.onEdit(item),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.accent,
                                    width: 3,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          child: InkWell(
                                            key: ValueKey(
                                              'planner-complete-${item.id}',
                                            ),
                                            onTap:
                                                widget.busyIds.contains(item.id)
                                                ? null
                                                : () => widget.onToggle(item),
                                            child:
                                                widget.busyIds.contains(item.id)
                                                ? const SizedBox.square(
                                                    dimension: 12,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 1.5,
                                                        ),
                                                  )
                                                : Icon(
                                                    item.completed
                                                        ? Icons.check_circle
                                                        : Icons
                                                              .radio_button_unchecked,
                                                    size: 16,
                                                    color: AppColors.accent,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            maxLines: height >= 64 ? 2 : 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              decoration: item.completed
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (height >= 48)
                                    Text(
                                      '${plannerClock(time)} · ${item.durationMinutes} мин · ${item.projectName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (samePlannerDay(widget.selectedDate, now))
                Positioned(
                  top: (now.hour + now.minute / 60) * hourHeight,
                  left: 54,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            height: 1,
                            thickness: 1.5,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
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

class _PlannerEditor extends StatefulWidget {
  const _PlannerEditor({
    this.item,
    required this.initialDate,
    required this.hour,
    required this.tasks,
    required this.projects,
  });
  final PlannerItemModel? item;
  final DateTime initialDate;
  final int hour;
  final List<ProjectTaskModel> tasks;
  final List<ProjectModel> projects;
  @override
  State<_PlannerEditor> createState() => _PlannerEditorState();
}

class _PlannerEditorState extends State<_PlannerEditor> {
  late final TextEditingController _title;
  late DateTime _date;
  late TimeOfDay _time;
  late int _duration;
  ProjectTaskModel? _task;
  InboxTaskModel? _inbox;
  String? _validation;
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item?.title ?? '');
    final scheduled = widget.item?.scheduledAt;
    final local = scheduled == null
        ? widget.initialDate
        : plannerLocal(scheduled);
    _date = plannerDate(local);
    _time = scheduled == null
        ? TimeOfDay(hour: widget.hour, minute: 0)
        : TimeOfDay(hour: local.hour, minute: local.minute);
    _duration = (widget.item?.durationMinutes ?? 30).clamp(15, 1440);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTask() async {
    setState(() => _picking = true);
    List<InboxTaskModel> inbox = [];
    try {
      if (sl.isRegistered<InboxRepository>()) {
        inbox = await sl<InboxRepository>().getInbox(archived: false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить Инбокс.')),
        );
      }
    }
    if (!mounted) return;
    setState(() => _picking = false);
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Добавить существующую задачу',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (widget.tasks.isEmpty && inbox.isEmpty)
                      const ListTile(title: Text('Нет доступных задач')),
                    for (final task in widget.tasks.where((e) => !e.archived))
                      ListTile(
                        title: Text(task.title),
                        subtitle: Text(
                          task.displayId.isEmpty ? 'Проект' : task.displayId,
                        ),
                        onTap: () => Navigator.pop(context, task),
                      ),
                    for (final task in inbox.where(
                      (e) => !e.archived && !e.isLocalOnly,
                    ))
                      ListTile(
                        title: Text(task.title),
                        subtitle: const Text('Инбокс'),
                        onTap: () => Navigator.pop(context, task),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _task = result is ProjectTaskModel ? result : null;
      _inbox = result is InboxTaskModel ? result : null;
      _title.text = _task?.title ?? _inbox!.title;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _validation = 'Введите название задачи');
      return;
    }
    final cubit = context.read<PlannerCubit>();
    final scheduled = plannerInstant(_date, _time.hour, _time.minute);
    final success = _task != null || _inbox != null
        ? await cubit.addTask(
            projectId: _task?.projectId,
            taskId: _task?.id,
            inboxTaskId: _inbox?.id,
            scheduledAt: scheduled,
            durationMinutes: _duration,
          )
        : await cubit.save(
            item: widget.item,
            title: _title.text,
            scheduledAt: scheduled,
            durationMinutes: _duration,
          );
    if (mounted && success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PlannerCubit, PlannerState>(
    builder: (context, state) {
      final saving = state.isSaving;
      final item = widget.item;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item == null ? 'Добавить в ежедневник' : 'Задача ежедневника',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  readOnly:
                      saving ||
                      (item != null && !item.isStandalone) ||
                      _task != null ||
                      _inbox != null,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    errorText: _validation,
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
                if (item == null)
                  TextButton.icon(
                    onPressed: saving || _picking ? null : _pickTask,
                    icon: const Icon(Icons.playlist_add),
                    label: Text(
                      _picking ? 'Загрузка…' : 'Из проекта или Инбокса',
                    ),
                  ),
                if (_task != null || _inbox != null)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            _task = null;
                            _inbox = null;
                            _title.clear();
                          }),
                    child: const Text('Создать новую задачу'),
                  ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(_heading(_date)),
                  onTap: saving
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (date != null && mounted) {
                            setState(() => _date = date);
                          }
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')} · GMT+5',
                  ),
                  onTap: saving
                      ? null
                      : () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _time,
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (time != null && mounted) {
                            setState(() => _time = time);
                          }
                        },
                ),
                DropdownButtonFormField<int>(
                  initialValue: _duration,
                  decoration: const InputDecoration(labelText: 'Длительность'),
                  items:
                      ({15, 30, 45, 60, 90, 120, 180, _duration}.toList()
                            ..sort())
                          .map(
                            (minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text('$minutes мин'),
                            ),
                          )
                          .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _duration = value!),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? 'Сохранение…' : 'Сохранить'),
                ),
                if (item?.taskId != null)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final cubit = context.read<PlannerCubit>();
                            final router = GoRouter.of(context);
                            navigator.pop();
                            await router.push(
                              '/tasks/${item!.taskId}',
                              extra: item.task,
                            );
                            if (!cubit.isClosed) await cubit.refresh();
                          },
                    child: const Text('Открыть задачу проекта'),
                  ),
                if (item != null)
                  TextButton(
                    onPressed: saving || state.busyIds.contains(item.id)
                        ? null
                        : () async {
                            await context.read<PlannerCubit>().remove(item);
                            if (context.mounted &&
                                !context.read<PlannerCubit>().state.items.any(
                                  (e) => e.id == item.id,
                                )) {
                              Navigator.pop(context);
                            }
                          },
                    child: const Text(
                      'Убрать из ежедневника',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _heading(DateTime day) =>
    '${_days[day.weekday - 1]}, ${day.day} ${_genitiveMonths[day.month - 1]}';
const _days = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];
const _shortDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _months = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];
const _genitiveMonths = [
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
