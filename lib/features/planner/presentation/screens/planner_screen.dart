import '../../../projects/domain/entities/project_task_model.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../tasks/domain/repositories/my_tasks_repository.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/repositories/google_calendar_repository.dart';
import '../cubit/google_calendar_cubit.dart';
import '../widgets/google_calendar_settings.dart';
import '../widgets/planner_day_agenda.dart';
import '../widgets/task_schedule_sheet.dart';
import '../widgets/planner_time_mode.dart';
import '../widgets/planner_untimed_list.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_form_surface.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../inbox/domain/repositories/inbox_repository.dart';
import '../../../inbox/domain/entities/inbox_task_model.dart';
import '../../data/models/planner_item_model.dart';
import '../../data/planner_changes.dart';
import '../../domain/utils/planner_dates.dart';
import '../cubit/planner_cubit.dart';
import '../cubit/planner_state.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

enum _View { day, week, month }

class _PlannerScreenState extends State<PlannerScreen>
    with WidgetsBindingObserver {
  GoogleCalendarCubit? _google;
  StreamSubscription<GoogleCalendarState>? _googleSubscription;
  DateTime _selectedDate = plannerDate(plannerNow());
  _View _view = _View.day;
  Timer? _clock;
  PlannerCubit? _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (sl.isRegistered<GoogleCalendarRepository>()) {
      _google = GoogleCalendarCubit(sl<GoogleCalendarRepository>());
      _googleSubscription = _google!.stream.listen((_) {
        if (mounted) setState(() {});
      });
      unawaited(_google!.range(_selectedDate));
    }
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= context.read<PlannerCubit?>();
    unawaited(_cubit?.initialize() ?? Future<void>.value());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _googleSubscription?.cancel();
    _google?.close();
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      unawaited(_google?.refresh() ?? Future<void>.value());
    }
  }

  Future<void> _calendarSettings() async {
    final google = _google;
    if (google == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GoogleCalendarSettings(cubit: google),
    );
  }

  Future<void> _refresh() async {
    await Future.wait([
      if (_cubit != null) _cubit!.refresh(),
      if (_google != null) _google!.refresh(),
    ]);
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = plannerDate(date));
    unawaited(_google?.range(_selectedDate) ?? Future<void>.value());
  }

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

  Future<void> _edit({
    PlannerItemModel? item,
    int? hour,
    TimeOfDay? assignedTime,
  }) async {
    if (item?.external == true) {
      await showAppDialog<void>(
        context: context,
        builder: (context) => AppDialog(
          title: Text(item!.title),
          content: Text(
            item.allDay
                ? 'Google Календарь · Весь день'
                : 'Google Календарь · ${_heading(plannerLocal(item.scheduledAt!))} · ${plannerClock(plannerLocal(item.scheduledAt!))}\nСобытия Google редактируются в Google Календаре.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
      return;
    }
    final cubit = _cubit;
    if (cubit == null) return;
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
          withTime: assignedTime != null || hour != null ? true : null,
          assignedTime: assignedTime,
        ),
      ),
    );
  }

  Future<void> _assignTime(PlannerItemModel item) async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Время начала',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (mounted && time != null) await _edit(item: item, assignedTime: time);
  }

  Future<void> _itemMenu(PlannerItemModel item) async {
    final action = await showAppActionMenu<String>(
      context,
      title: item.displayTitle,
      groups: [
        [
          if (item.scheduledAt != null)
            const AppMenuAction(
              value: 'untimed',
              label: 'Без времени',
              icon: LucideIcons.clock,
            ),
          if (item.scheduledAt == null)
            const AppMenuAction(
              value: 'time',
              label: 'Назначить время',
              icon: LucideIcons.clock,
            ),
          const AppMenuAction(
            value: 'edit',
            label: 'Изменить день и запись',
            icon: LucideIcons.calendarDays,
          ),
          const AppMenuAction(
            value: 'remove',
            label: 'Убрать из ежедневника',
            icon: LucideIcons.calendarMinus,
            destructive: true,
          ),
        ],
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'time':
        await _assignTime(item);
      case 'edit':
        await _edit(item: item);
      case 'remove':
        await _cubit?.remove(item);
      case 'untimed':
        await _cubit?.save(
          item: item,
          title: item.title,
          scheduledAt: null,
          plannedDate: item.day ?? _selectedDate,
          durationMinutes: item.durationMinutes,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = _cubit == null
        ? _scaffold(const PlannerState())
        : BlocConsumer<PlannerCubit, PlannerState>(
            listenWhen: (a, b) => a.actionRevision != b.actionRevision,
            listener: (context, state) {
              if (state.actionError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  appSnackBar(
                    context: context,
                    tone: AppSnackBarTone.error,
                    content: Text(state.actionError!),
                  ),
                );
              }
            },
            builder: (_, state) => _scaffold(state),
          );
    return screen;
  }

  Widget _dateToolbar(GoogleCalendarState? google) {
    final dateSelector = InkWell(
      key: const Key('planner-date-picker'),
      onTap: _pickDate,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: AppIconSizes.standard,
            ),
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
              size: AppIconSizes.standard,
            ),
          ],
        ),
      ),
    );
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('planner-previous-day'),
          constraints: const BoxConstraints.tightFor(width: 40, height: 48),
          padding: EdgeInsets.zero,
          tooltip: 'Назад',
          onPressed: () => _move(-1),
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: AppIconSizes.standard,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            textStyle: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => _selectDate(plannerNow()),
          child: const Text('Сегодня'),
        ),
        IconButton(
          key: const Key('planner-next-day'),
          constraints: const BoxConstraints.tightFor(width: 40, height: 48),
          padding: EdgeInsets.zero,
          tooltip: 'Вперёд',
          onPressed: () => _move(1),
          icon: const Icon(
            Icons.chevron_right_rounded,
            size: AppIconSizes.standard,
          ),
        ),
      ],
    );
    return Row(
      children: [
        if (_google != null) ...[
          IconButton(
            key: const Key('planner-calendar-sources'),
            constraints: const BoxConstraints.tightFor(width: 40, height: 48),
            padding: EdgeInsets.zero,
            tooltip: 'Источники календаря',
            onPressed: _calendarSettings,
            icon: Icon(
              LucideIcons.calendars,
              size: AppIconSizes.standard,
              color: google?.connection.connected == true
                  ? AppColors.accent
                  : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(child: dateSelector),
              navigation,
            ],
          ),
        ),
      ],
    );
  }

  Widget _scaffold(PlannerState state) {
    final google = _google?.state;
    final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final rangeStart = DateTime(
      monthStart.year,
      monthStart.month,
      2 - monthStart.weekday,
    );
    final items = [
      ...state.items.where((e) => !e.archived),
      if (google?.showEvents == true)
        for (final event in google!.events)
          ...event.entries(
            rangeStart,
            rangeStart.add(const Duration(days: 42)),
          ),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const DashboardAppBar(accountTitle: 'Ежедневник'),
      floatingActionButton: _cubit == null
          ? null
          : FloatingActionButton.small(
              key: const Key('planner-add'),
              tooltip: 'Добавить задачу',
              onPressed: state.isSaving ? null : () => _edit(),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add, size: AppIconSizes.standard),
            ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          key: const Key('planner-pull-to-refresh'),
          color: AppColors.accent,
          onRefresh: _refresh,
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
                          ButtonSegment(
                            value: _View.week,
                            label: Text('Неделя'),
                          ),
                          ButtonSegment(
                            value: _View.month,
                            label: Text('Месяц'),
                          ),
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
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: _dateToolbar(google),
              ),
              if (state.status == PlannerStatus.loading ||
                  google?.loading == true)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.accent,
                ),
              if (state.error != null)
                MaterialBanner(
                  content: Text(state.error!),
                  actions: [const Text('Потяните вниз, чтобы повторить')],
                ),
              if (google?.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          google!.error!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _google?.refresh(),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              if (_view == _View.week) _weekStrip(items),
              Expanded(
                child: _view == _View.month
                    ? _monthGrid(items)
                    : GestureDetector(
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() > 180) {
                            _move(velocity < 0 ? 1 : -1);
                          }
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
                            if (items.any(
                              (e) =>
                                  e.allDay &&
                                  e.scheduledAt != null &&
                                  samePlannerDay(
                                    plannerLocal(e.scheduledAt!),
                                    _selectedDate,
                                  ),
                            ))
                              SizedBox(
                                height: 38,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  children: [
                                    for (final item in items.where(
                                      (e) =>
                                          e.allDay &&
                                          e.scheduledAt != null &&
                                          samePlannerDay(
                                            plannerLocal(e.scheduledAt!),
                                            _selectedDate,
                                          ),
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: ActionChip(
                                          avatar: const Icon(
                                            Icons.event,
                                            size: 16,
                                          ),
                                          label: Text(item.title),
                                          onPressed: () => _edit(item: item),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (items.any(
                              (e) =>
                                  e.scheduledAt == null &&
                                  (e.plannedDate == null ||
                                      samePlannerDay(
                                        e.plannedDate!,
                                        _selectedDate,
                                      )),
                            ))
                              _unscheduled(
                                items
                                    .where(
                                      (e) =>
                                          e.scheduledAt == null &&
                                          (e.plannedDate == null ||
                                              samePlannerDay(
                                                e.plannedDate!,
                                                _selectedDate,
                                              )),
                                    )
                                    .toList(),
                              ),
                            Expanded(
                              child: _view == _View.day
                                  ? PlannerDayAgenda(
                                      key: ValueKey('agenda-$_selectedDate'),
                                      selectedDate: _selectedDate,
                                      now: plannerNow(),
                                      items: items,
                                      busyIds: state.busyIds,
                                      onCreate: () => _edit(),
                                      onEdit: (item) => _edit(item: item),
                                      onToggle: (item) => _cubit?.toggle(item),
                                      onMenu: (item) => _itemMenu(item),
                                      hasUntimedPlans: items.any(
                                        (item) =>
                                            item.scheduledAt == null &&
                                            item.plannedDate != null &&
                                            samePlannerDay(
                                              item.plannedDate!,
                                              _selectedDate,
                                            ),
                                      ),
                                    )
                                  : _DayTimeline(
                                      key: ValueKey(_selectedDate),
                                      selectedDate: _selectedDate,
                                      items: items
                                          .where(
                                            (e) =>
                                                !e.allDay &&
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
                                      onToggle: (item) {
                                        if (!item.external) {
                                          _cubit?.toggle(item);
                                        }
                                      },
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
      ),
    );
  }

  Widget _unscheduled(List<PlannerItemModel> items) => PlannerUntimedList(
    items: items,
    busyIds: _cubit?.state.busyIds ?? {},
    onAssign: (item) =>
        item.plannedDate == null ? _edit(item: item) : _assignTime(item),
    onMenu: _itemMenu,
    onToggle: (item) => _cubit?.toggle(item),
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
                        (e) => e.day != null && samePlannerDay(e.day!, day),
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
              physics: const AlwaysScrollableScrollPhysics(),
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
                    .where((e) => e.day != null && samePlannerDay(e.day!, day))
                    .toList();
                return InkWell(
                  key: ValueKey('planner-month-${day.toIso8601String()}'),
                  onTap: () {
                    setState(() => _view = _View.day);
                    _selectDate(day);
                  },
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
                          Row(
                            children: [
                              if (item.inboxTaskId != null) ...[
                                const Icon(
                                  Icons.inbox_outlined,
                                  size: AppIconSizes.standard,
                                  color: AppColors.accent,
                                  semanticLabel: 'Из Инбокса',
                                ),
                                const SizedBox(width: 2),
                              ],
                              Expanded(
                                child: Text(
                                  item.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (events.length > 2)
                          Text(
                            '+${events.length - 2}',
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
      physics: const AlwaysScrollableScrollPhysics(),
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
                        maxSimultaneousDrags:
                            item.external || widget.busyIds.contains(item.id)
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
                              item.displayTitle,
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
                          color: item.completed
                              ? const Color(0xFFF1EFFB)
                              : const Color(0xFFE8E4FA),
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          child: InkWell(
                                            key: ValueKey(
                                              'planner-complete-${item.id}',
                                            ),
                                            onTap:
                                                item.external ||
                                                    widget.busyIds.contains(
                                                      item.id,
                                                    )
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
                                                    item.external
                                                        ? Icons.event_outlined
                                                        : item.completed
                                                        ? Icons.check_circle
                                                        : Icons
                                                              .radio_button_unchecked,
                                                    size: AppIconSizes.standard,
                                                    color: AppColors.accent,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (item.inboxTaskId != null) ...[
                                          const Icon(
                                            Icons.inbox_outlined,
                                            size: AppIconSizes.standard,
                                            color: AppColors.accent,
                                            semanticLabel: 'Из Инбокса',
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            item.displayTitle,
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

Future<void> showScheduleProjectTask(
  BuildContext context,
  ProjectTaskModel task,
) => _showScheduleTask(context, task: task);

Future<void> showScheduleInboxTask(BuildContext context, InboxTaskModel task) =>
    _showScheduleTask(context, inboxTask: task);

Future<void> _showScheduleTask(
  BuildContext context, {
  ProjectTaskModel? task,
  InboxTaskModel? inboxTask,
}) async {
  final saved = await showModalBottomSheet<TaskScheduleResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => BlocProvider(
      create: (_) => sl<PlannerCubit>()..initialize(),
      child: TaskScheduleSheet(
        title: task?.title ?? inboxTask!.title,
        source: task == null
            ? 'Инбокс'
            : task.displayId.isEmpty
            ? 'Задача проекта'
            : task.displayId,
        projectId: task?.projectId,
        taskId: task?.id,
        inboxTaskId: inboxTask?.id,
      ),
    ),
  );
  if (saved != null) {
    notifyPlannerChanges();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context: context,
        tone: AppSnackBarTone.success,
        description: task?.title ?? inboxTask!.title,
        content: Text(
          saved == TaskScheduleResult.added
              ? 'Задача добавлена в ежедневник'
              : 'План в ежедневнике обновлён',
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
    this.withTime,
    this.assignedTime,
  });
  final PlannerItemModel? item;
  final DateTime initialDate;
  final int hour;
  final bool? withTime;
  final TimeOfDay? assignedTime;
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
  String? _removeError;
  bool _removing = false;
  bool _picking = false;
  late bool _hasTime;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.item?.title ?? _task?.title ?? _inbox?.title ?? '',
    );
    final scheduled = widget.item?.scheduledAt;
    final local = scheduled == null
        ? widget.initialDate
        : plannerLocal(scheduled);
    _date = widget.item?.day ?? plannerDate(local);
    _hasTime = widget.withTime ?? (scheduled != null);
    _time = scheduled == null
        ? TimeOfDay(hour: widget.hour, minute: 0)
        : TimeOfDay(hour: local.hour, minute: local.minute);
    _time = widget.assignedTime ?? _time;
    _duration = (widget.item?.durationMinutes ?? 30).clamp(15, 1440);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTask() async {
    if (_picking) return;
    FocusScope.of(context).unfocus();
    setState(() => _picking = true);
    List<ProjectTaskModel> tasks = [];
    List<InboxTaskModel> inbox = [];
    final errors = <String>[];
    // Sources are read only after an explicit request to choose a task.
    await Future.wait<void>([
      () async {
        if (!sl.isRegistered<MyTasksRepository>() ||
            !sl.isRegistered<ProfileRepository>()) {
          return;
        }
        try {
          final profile = await sl<ProfileRepository>().getCurrentUser();
          tasks = await sl<MyTasksRepository>().getTasks(
            assigneeId: profile.id,
          );
        } catch (_) {
          errors.add('Не удалось загрузить задачи проектов.');
        }
      }(),
      () async {
        if (!sl.isRegistered<InboxRepository>()) return;
        try {
          inbox = await sl<InboxRepository>().getInbox(archived: false);
        } catch (_) {
          errors.add('Не удалось загрузить Инбокс.');
        }
      }(),
    ]);
    if (!mounted) return;
    setState(() => _picking = false);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.error,
          content: Text(errors.join('\n')),
        ),
      );
    }
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
                    if (tasks.isEmpty && inbox.isEmpty)
                      const ListTile(title: Text('Нет доступных задач')),
                    for (final task in tasks.where((e) => !e.archived))
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
    final scheduled = _hasTime
        ? plannerInstant(_date, _time.hour, _time.minute)
        : null;
    final success = _task != null || _inbox != null
        ? await cubit.addTask(
            projectId: _task?.projectId,
            taskId: _task?.id,
            inboxTaskId: _inbox?.id,
            scheduledAt: scheduled,
            plannedDate: _hasTime ? null : _date,
            durationMinutes: _duration,
          )
        : await cubit.save(
            item: widget.item,
            title: _title.text,
            scheduledAt: scheduled,
            plannedDate: _hasTime ? null : _date,
            durationMinutes: _duration,
          );
    if (mounted && success) Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    final item = widget.item;
    if (item == null || _removing) return;
    final cubit = context.read<PlannerCubit>();
    setState(() {
      _removing = true;
      _removeError = null;
    });
    final removed = await cubit.remove(item);
    if (!mounted) return;
    if (removed) {
      Navigator.pop(context);
    } else {
      setState(() {
        _removing = false;
        _removeError =
            cubit.state.actionError ??
            'Не удалось убрать запись из ежедневника. Повторите попытку.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PlannerCubit, PlannerState>(
    builder: (context, state) {
      final saving = state.isSaving || _removing;
      final item = widget.item;
      return AppFormSurface(
        child: SafeArea(
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
                    item == null
                        ? 'Добавить в ежедневник'
                        : 'Задача ежедневника',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    label: 'Название',
                    child: TextField(
                      controller: _title,
                      readOnly:
                          saving ||
                          (item != null && !item.isStandalone) ||
                          _task != null ||
                          _inbox != null,
                      decoration: InputDecoration(
                        hintText: 'Введите название',
                        errorText: _validation,
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                  if (item == null)
                    TextButton.icon(
                      onPressed: saving || _picking ? null : _pickTask,
                      icon: const Icon(
                        Icons.playlist_add,
                        size: AppIconSizes.standard,
                      ),
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
                  const SizedBox(height: 8),
                  ListTile(
                    key: const Key('planner-editor-date'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_month_outlined,
                      size: AppIconSizes.standard,
                    ),
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
                  const SizedBox(height: 8),
                  PlannerTimeMode(
                    hasTime: _hasTime,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => _hasTime = value),
                  ),
                  if (_hasTime) ...[
                    ListTile(
                      key: const Key('planner-editor-time'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.schedule,
                        size: AppIconSizes.standard,
                      ),
                      title: Text(_time.format(context)),
                      onTap: saving
                          ? null
                          : () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _time,
                              );
                              if (time != null && mounted) {
                                setState(() => _time = time);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    AppFormField(
                      label: 'Длительность',
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _duration,
                        decoration: const InputDecoration(
                          hintText: 'Выберите длительность',
                        ),
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
                    ),
                  ],
                  const SizedBox(height: 20),
                  AppFormButton(
                    key: const Key('planner-editor-save'),
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
                  if (item != null && _removeError != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _removeError!,
                          key: const Key('planner-remove-error'),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ),
                  if (item != null)
                    TextButton(
                      key: const Key('planner-remove'),
                      onPressed: saving || state.busyIds.contains(item.id)
                          ? null
                          : _remove,
                      child: Text(
                        _removing ? 'Удаление…' : 'Убрать из ежедневника',
                        style: const TextStyle(color: AppColors.error),
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
