import '../cubit/planner_week_order_cubit.dart';
import '../../../../core/widgets/app_floating_action_button_location.dart';
import '../widgets/planner_day_week_strip.dart';
import 'package:jospar/core/localization/app_translations.dart';
import '../widgets/planner_day_agenda.dart';
import 'package:forui/forui.dart';
import '../widgets/planner_entry_extras.dart';
import '../../../../core/widgets/task_completion_indicator.dart';
import '../widgets/planner_task_picker.dart';
import '../widgets/planner_date_picker.dart';
import '../widgets/planner_time_field.dart';
import '../widgets/planner_week_view.dart';
import '../../../projects/domain/entities/project_task_model.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../tasks/domain/repositories/my_tasks_repository.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/repositories/google_calendar_repository.dart';
import '../cubit/google_calendar_cubit.dart';
import '../widgets/google_calendar_settings.dart';
import '../widgets/task_schedule_sheet.dart';
import '../widgets/planner_time_mode.dart';
import '../widgets/planner_untimed_list.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_ui_tokens.dart';
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
  PlannerWeekOrderCubit? _weekOrder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (sl.isRegistered<PlannerWeekOrderCubit>()) {
      _weekOrder = sl<PlannerWeekOrderCubit>()..initialize();
    }
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
    _weekOrder?.close();
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      unawaited(_refresh());
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
    final date = await showPlannerDatePicker(
      context: context,
      initialDate: _selectedDate,
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
                ? tr(context, 'Google Календарь · Весь день')
                : tr(
                    context,
                    "Google Календарь · {p0} · {p1}\nСобытия Google редактируются в Google Календаре.",
                    {
                      'p0': _heading(plannerLocal(item.scheduledAt!)),
                      'p1': plannerClock(plannerLocal(item.scheduledAt!)),
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Закрыть')),
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
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: AppColors.of(context).canvas,
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
            AppMenuAction(
              value: 'untimed',
              label: tr(context, 'Весь день'),
              icon: LucideIcons.clock,
            ),
          if (item.scheduledAt == null)
            AppMenuAction(
              value: 'time',
              label: tr(context, 'Назначить время'),
              icon: LucideIcons.clock,
            ),
          AppMenuAction(
            value: 'edit',
            label: tr(context, 'Изменить день и запись'),
            icon: LucideIcons.calendarDays,
          ),
          AppMenuAction(
            value: 'remove',
            label: tr(context, 'Убрать из ежедневника'),
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

  Widget _dateToolbar(
    GoogleCalendarState? google,
    List<PlannerItemModel> items,
  ) {
    final dateSelector = InkWell(
      key: const Key('planner-date-picker'),
      borderRadius: BorderRadius.circular(10),
      onTap: _pickDate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.of(context).ink,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.of(context).muted,
            ),
          ],
        ),
      ),
    );
    final label = switch (_view) {
      _View.day => 'День',
      _View.week => 'Неделя',
      _View.month => 'Месяц',
    };
    final selectedDay = plannerDate(_selectedDate);
    final start = switch (_view) {
      _View.day => selectedDay,
      _View.week => selectedDay.subtract(
        Duration(days: selectedDay.weekday - 1),
      ),
      _View.month => DateTime(selectedDay.year, selectedDay.month, 1),
    };
    final end = switch (_view) {
      _View.day => DateTime(start.year, start.month, start.day + 1),
      _View.week => DateTime(start.year, start.month, start.day + 7),
      _View.month => DateTime(start.year, start.month + 1, 1),
    };
    final count = items.where((item) {
      final day = item.scheduledAt == null
          ? item.day
          : plannerLocal(item.scheduledAt!);
      return day != null && !day.isBefore(start) && day.isBefore(end);
    }).length;
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.of(context).subtleSurface,
            border: Border.all(color: AppColors.of(context).border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('planner-previous-day'),
                  tooltip: tr(context, 'Предыдущий период'),
                  onPressed: () => _move(-1),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(32, 36),
                    minimumSize: const Size(32, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.of(context).ink,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 7,
                  endIndent: 7,
                  color: AppColors.of(context).border,
                ),
                InkWell(
                  key: const Key('planner-view-selector'),
                  onTap: () => setState(() {
                    _view = switch (_view) {
                      _View.day => _View.week,
                      _View.week => _View.month,
                      _View.month => _View.day,
                    };
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(context).ink,
                        ),
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 7,
                  endIndent: 7,
                  color: AppColors.of(context).border,
                ),
                IconButton(
                  key: const Key('planner-next-day'),
                  tooltip: tr(context, 'Следующий период'),
                  onPressed: () => _move(1),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(32, 36),
                    minimumSize: const Size(32, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.of(context).ink,
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: tr(context, "Записей с датой за выбранный период: {p0}", {
            'p0': count,
          }),
          child: Container(
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.of(context).outgoingMessage,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
    final connected = google?.connection.connected == true;
    final sources = _google == null
        ? null
        : IconButton(
            key: const Key('planner-calendar-sources'),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(36),
              minimumSize: const Size.square(36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              backgroundColor: connected
                  ? AppColors.of(context).outgoingMessage
                  : AppColors.of(context).subtleSurface,
              foregroundColor: connected
                  ? AppColors.accent
                  : AppColors.of(context).ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: connected
                      ? AppColors.accent.withValues(alpha: 0.25)
                      : AppColors.of(context).border,
                ),
              ),
            ),
            tooltip: tr(context, 'Источники календаря'),
            onPressed: _calendarSettings,
            icon: const Icon(LucideIcons.calendars, size: 18),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Row(
          children: [
            if (sources != null) ...[
              sources,
              SizedBox(width: compact ? 4 : 10),
            ],
            Expanded(child: dateSelector),
            SizedBox(width: compact ? 4 : 8),
            navigation,
          ],
        );
      },
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
      backgroundColor: AppColors.of(context).canvas,
      appBar: const DashboardAppBar(accountTitle: 'Ежедневник'),
      floatingActionButtonLocation: AppFloatingActionButtonLocation(context),
      floatingActionButton: _cubit == null
          ? null
          : FloatingActionButton(
              key: const Key('planner-add'),
              tooltip: tr(context, 'Добавить задачу'),
              shape: const CircleBorder(),
              elevation: 2,
              highlightElevation: 4,
              onPressed: state.isSaving ? null : () => _edit(),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 30),
            ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          key: const Key('planner-pull-to-refresh'),
          color: AppColors.accent,
          onRefresh: _refresh,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.of(context).canvas,
                  border: Border(
                    bottom: BorderSide(color: AppColors.of(context).border),
                  ),
                ),
                child: _dateToolbar(google, items),
              ),
              if (state.status == PlannerStatus.loading ||
                  google?.loading == true)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.accent,
                ),
              if (state.error != null)
                MaterialBanner(
                  content: Text(tr(context, state.error!)),
                  actions: [
                    Text(tr(context, 'Потяните вниз, чтобы повторить')),
                  ],
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
                        child: Text(tr(context, 'Повторить')),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _view == _View.month
                    ? _monthGrid(items)
                    : _view == _View.week
                    ? PlannerWeekView(
                        orderCubit: _weekOrder,
                        onRemove: (item) => _cubit?.remove(item),
                        selectedDate: _selectedDate,
                        items: items,
                        busyIds: state.busyIds,
                        saving: state.isSaving,
                        onEdit: (item) => _edit(item: item),
                        onToggle: (item) => _cubit?.toggle(item),
                        onCreate: _cubit == null
                            ? null
                            : (day, title, time) => _cubit!.save(
                                title: title,
                                scheduledAt: time == null
                                    ? null
                                    : plannerInstant(
                                        day,
                                        time.hour,
                                        time.minute,
                                      ),
                                plannedDate: time == null ? day : null,
                                durationMinutes: 30,
                              ),
                      )
                    : GestureDetector(
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() > 180) {
                            _move(velocity < 0 ? 1 : -1);
                          }
                        },
                        child: Column(
                          children: [
                            PlannerDayWeekStrip(
                              selectedDate: _selectedDate,
                              onSelected: _selectDate,
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
                            _allDayArea(items),
                            Expanded(
                              child: _view == _View.day
                                  ? PlannerDayAgenda(
                                      key: ValueKey('agenda-$_selectedDate'),
                                      selectedDate: _selectedDate,
                                      now: plannerNow(),
                                      items: items,
                                      busyIds: state.busyIds,
                                      onCreate: () => _edit(),
                                      onSchedule:
                                          state.isSaving ||
                                              state.busyIds.isNotEmpty
                                          ? null
                                          : (item, time) => _cubit?.save(
                                              item: item,
                                              title: item.title,
                                              scheduledAt: time,
                                              durationMinutes:
                                                  item.durationMinutes,
                                            ),
                                      enableUntimedDrag:
                                          !state.isSaving &&
                                          state.busyIds.isEmpty,
                                      onEdit: (item) => _edit(item: item),
                                      onToggle: (item) => _cubit?.toggle(item),
                                      onMenu: (item) => _itemMenu(item),
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
                                      onMenu: (item) => _itemMenu(item),
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

  Widget _allDayArea(List<PlannerItemModel> items) {
    final untimed = items
        .where(
          (item) =>
              item.scheduledAt == null &&
              (item.plannedDate == null ||
                  samePlannerDay(item.plannedDate!, _selectedDate)),
        )
        .toList();
    if (_view != _View.day) {
      return untimed.isEmpty ? const SizedBox.shrink() : _unscheduled(untimed);
    }
    bool accepts(PlannerItemModel item) =>
        _cubit != null &&
        !_cubit!.state.isSaving &&
        _cubit!.state.busyIds.isEmpty &&
        !item.external &&
        !item.archived &&
        item.scheduledAt != null &&
        samePlannerDay(plannerLocal(item.scheduledAt!), _selectedDate) &&
        _cubit!.state.items.any(
          (current) =>
              current.id == item.id &&
              !current.archived &&
              current.scheduledAt != null,
        );
    return DragTarget<PlannerItemModel>(
      key: ValueKey('planner-all-day-drop-${plannerDayString(_selectedDate)}'),
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) {
        if (!accepts(details.data)) return;
        final item = _cubit!.state.items.firstWhere(
          (item) => item.id == details.data.id,
        );
        _cubit!.save(
          item: item,
          title: item.title,
          scheduledAt: null,
          plannedDate: _selectedDate,
          durationMinutes: item.durationMinutes,
          reminderMinutes: 0,
        );
      },
      builder: (context, candidates, rejected) => ColoredBox(
        color: candidates.isEmpty
            ? Colors.transparent
            : AppColors.of(context).accent.withValues(alpha: .12),
        child: untimed.isNotEmpty
            ? _unscheduled(untimed)
            : Container(
                height: 44,
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: candidates.isEmpty
                          ? AppColors.of(context).border
                          : AppColors.of(context).accent,
                    ),
                  ),
                ),
                child: Text(
                  tr(
                    context,
                    candidates.isEmpty ? 'Весь день' : 'Отпустите: весь день',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: candidates.isEmpty
                        ? AppColors.of(context).muted
                        : AppColors.of(context).accent,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _unscheduled(List<PlannerItemModel> items) => PlannerUntimedList(
    items: items,
    enableDrag:
        _view == _View.day &&
        _cubit != null &&
        !_cubit!.state.isSaving &&
        _cubit!.state.busyIds.isEmpty,
    busyIds: _cubit?.state.isSaving == true
        ? items.map((item) => item.id).toSet()
        : _cubit?.state.busyIds ?? {},
    onAssign: (item) =>
        item.plannedDate == null ? _edit(item: item) : _assignTime(item),
    onMenu: _itemMenu,
    onToggle: (item) => _cubit?.toggle(item),
  );

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
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.of(context).muted,
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
                        color: AppColors.of(
                          context,
                        ).border.withValues(alpha: 0.5),
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
                                : AppColors.of(context).muted,
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
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.of(context).muted,
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
    required this.onMenu,
  });
  final DateTime selectedDate;
  final List<PlannerItemModel> items;
  final Set<String> busyIds;
  final ValueChanged<int> onCreate;
  final ValueChanged<PlannerItemModel> onEdit, onToggle, onMenu;
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
    final hour = dates.isEmpty
        ? 6
        : dates.first.hour < 6
        ? 0
        : dates.first.hour > 18
        ? 18
        : 6;
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
                            hour >= 6 && hour <= 18 && hour % 3 == 0
                                ? '$hour:00'
                                : '',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.of(context).muted,
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
                                  left: BorderSide(
                                    color: AppColors.of(context).border,
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
              for (final hour in [6, 9, 12, 15, 18])
                Positioned(
                  top: hour * hourHeight + 7,
                  left: 53,
                  width: 9,
                  child: IgnorePointer(
                    child: Divider(
                      height: 1,
                      color: AppColors.of(context).border,
                    ),
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
                      key: ValueKey('planner-agenda-${item.id}'),
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
                            key: ValueKey('planner-open-${item.id}'),
                            onTap: () => widget.onEdit(item),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: const Border(
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
                                                : item.external
                                                ? const Icon(
                                                    Icons.event_outlined,
                                                    size: AppIconSizes.standard,
                                                  )
                                                : TaskCompletionIndicator(
                                                    completed: item.completed,
                                                    size: AppIconSizes.standard,
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
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              decoration: item.completed
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (!item.external)
                                          SizedBox.square(
                                            dimension: 24,
                                            child: IconButton(
                                              key: ValueKey(
                                                'planner-item-menu-${item.id}',
                                              ),
                                              tooltip: tr(
                                                context,
                                                'Действия записи',
                                              ),
                                              padding: EdgeInsets.zero,
                                              iconSize: 16,
                                              onPressed:
                                                  widget.busyIds.contains(
                                                    item.id,
                                                  )
                                                  ? null
                                                  : () => widget.onMenu(item),
                                              icon: const Icon(
                                                LucideIcons.ellipsis,
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
    backgroundColor: AppColors.of(context).canvas,
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
              ? tr(context, 'Задача добавлена в ежедневник')
              : tr(context, 'План в ежедневнике обновлён'),
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
  late int _reminder;
  ProjectTaskModel? _task;
  InboxTaskModel? _inbox;
  String? _validation;
  String? _removeError;
  String? _saveError;
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
    _reminder = widget.item?.reminderMinutes ?? 0;
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
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => PlannerTaskPicker(tasks: tasks, inbox: inbox),
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
    setState(() => _saveError = null);
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
            reminderMinutes: widget.item == null
                ? null
                : _hasTime
                ? _reminder
                : 0,
            title: _title.text,
            scheduledAt: scheduled,
            plannedDate: _hasTime ? null : _date,
            durationMinutes: _duration,
          );
    if (mounted && success) Navigator.pop(context, true);
    if (mounted && !success) {
      setState(
        () => _saveError =
            cubit.state.actionError ?? 'Не удалось сохранить изменения.',
      );
    }
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

  Future<void> _chooseDate() async {
    final date = await showPlannerDatePicker(
      context: context,
      initialDate: _date,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _chooseTime() async {
    final time = await showPlannerTimePicker(context, _time);
    if (time != null && mounted) {
      setState(() {
        _time = time;
        _hasTime = true;
      });
    }
  }

  Widget _entryView(PlannerItemModel item, PlannerState state, bool saving) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final neutral = dark ? const Color(0xFF242424) : const Color(0xFFF7F7F7);
    final fBase = dark ? FTheme.neutral.dark.touch : FTheme.neutral.light.touch;
    final source = item.inboxTaskId != null
        ? 'Инбокс'
        : item.isStandalone
        ? 'Ежедневник'
        : item.projectName;
    Widget caption(String text) => Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, color: colors.onSurfaceVariant),
    );
    Widget picker(Key key, String label, String value, VoidCallback action) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            caption(label),
            const SizedBox(height: 6),
            Material(
              color: neutral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: .6),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: key,
                onTap: saving ? null : action,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    return FTheme(
      data: FThemeData(
        touch: true,
        colors: fBase.colors.copyWith(
          primary: AppColors.accent,
          primaryForeground: Colors.white,
        ),
      ),
      child: AppFormSurface(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlocBuilder<PlannerCubit, PlannerState>(
                      buildWhen: (before, after) =>
                          _currentEntry(before)?.completed !=
                              _currentEntry(after)?.completed ||
                          before.isSaving != after.isSaving,
                      builder: (context, latest) {
                        final current = _currentEntry(latest) ?? item;
                        return IconButton(
                          key: const Key('planner-entry-complete'),
                          tooltip: current.completed
                              ? tr(context, 'Вернуть в план')
                              : tr(context, 'Отметить выполненной'),
                          onPressed: latest.isSaving || _removing
                              ? null
                              : () {
                                  final cubit = context.read<PlannerCubit>();
                                  unawaited(
                                    cubit.toggle(
                                      _currentEntry(cubit.state) ?? current,
                                    ),
                                  );
                                },
                          icon: TaskCompletionIndicator(
                            completed: current.completed,
                            size: 22,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const Key('planner-editor-title'),
                            controller: _title,
                            readOnly: saving || !item.isStandalone,
                            decoration: InputDecoration(
                              hintText: tr(context, 'Введите название'),
                              errorText: trn(context, _validation),
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 6),
                          caption(source),
                          if (item.creatorName?.trim().isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text.rich(
                                TextSpan(
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  children: [
                                    TextSpan(text: tr(context, 'Создал(а): ')),
                                    TextSpan(
                                      text: item.creatorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Закрыть'),
                      onPressed: saving ? null : () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                BlocBuilder<PlannerCubit, PlannerState>(
                  buildWhen: (before, after) =>
                      _currentEntry(before)?.icon !=
                          _currentEntry(after)?.icon ||
                      before.isSaving != after.isSaving,
                  builder: (context, latest) => PlannerIconSelector(
                    item: _currentEntry(latest) ?? item,
                    enabled: !saving && !latest.isSaving,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1),
                ),
                PlannerTimeMode(
                  hasTime: _hasTime,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _hasTime = value),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: picker(
                        const Key('planner-editor-date'),
                        'Дата задачи',
                        '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                        _chooseDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: picker(
                        const Key('planner-editor-time'),
                        'Время задачи',
                        _hasTime
                            ? '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'
                            : 'Весь день',
                        _chooseTime,
                      ),
                    ),
                  ],
                ),
                if (_hasTime) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.bell,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: const Key('planner-entry-reminder'),
                          initialValue: _reminder,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true),
                          items:
                              {
                                    0: 'Без напоминания',
                                    5: 'За 5 минут',
                                    15: 'За 15 минут',
                                    30: 'За 30 минут',
                                    60: 'За 1 час',
                                    120: 'За 2 часа',
                                    1440: 'За 1 день',
                                    if (![
                                      0,
                                      5,
                                      15,
                                      30,
                                      60,
                                      120,
                                      1440,
                                    ].contains(_reminder))
                                      _reminder: 'За $_reminder мин',
                                  }.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(
                                        entry.value,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: saving
                              ? null
                              : (value) =>
                                    setState(() => _reminder = value ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: caption('Длительность')),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<int>(
                          initialValue: _duration,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true),
                          items:
                              ({
                                    15,
                                    30,
                                    45,
                                    60,
                                    90,
                                    120,
                                    180,
                                    _duration,
                                  }.toList()..sort())
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        tr(context, "{p0} мин", {'p0': value}),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: saving
                              ? null
                              : (value) =>
                                    setState(() => _duration = value ?? 30),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                FButton(
                  key: const Key('planner-editor-save'),
                  onPress: saving ? null : _save,
                  child: Flexible(
                    child: Text(
                      saving
                          ? tr(context, 'Сохранение…')
                          : tr(context, 'Сохранить дату и время'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _saveError!,
                        key: const Key('planner-entry-save-error'),
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
                if (item.isStandalone) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1),
                  ),
                  BlocBuilder<PlannerCubit, PlannerState>(
                    buildWhen: (before, after) =>
                        _currentEntry(before) != _currentEntry(after) ||
                        before.busyIds.contains(item.id) !=
                            after.busyIds.contains(item.id) ||
                        before.isSaving != after.isSaving,
                    builder: (context, latest) => PlannerChecklistsPanel(
                      item: _currentEntry(latest) ?? item,
                      enabled:
                          !saving &&
                          !latest.isSaving &&
                          !latest.busyIds.contains(item.id),
                    ),
                  ),
                ],
                if (!item.isStandalone && item.taskId != null)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final router = GoRouter.of(context);
                            final cubit = context.read<PlannerCubit>();
                            Navigator.pop(context);
                            await router.push(
                              '/tasks/${item.taskId}',
                              extra: item.task,
                            );
                            if (!cubit.isClosed) await cubit.refresh();
                          },
                    child: Text(tr(context, 'Открыть задачу проекта')),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                if (_removeError != null)
                  Text(
                    _removeError!,
                    key: const Key('planner-remove-error'),
                    style: TextStyle(color: colors.error),
                  ),
                TextButton(
                  key: const Key('planner-remove'),
                  onPressed: saving ? null : _remove,
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: colors.error,
                  ),
                  child: Text(
                    _removing
                        ? tr(context, 'Удаление…')
                        : tr(context, 'Убрать из ежедневника'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PlannerItemModel? _currentEntry(PlannerState state) =>
      state.items.where((entry) => entry.id == widget.item?.id).firstOrNull;

  // Extras have their own subscriptions. Keep the form and its focus/scroll
  // stable while checklist writes enter and leave the item's busy state.
  Object? _formEntry(PlannerState state) {
    final item = _currentEntry(state);
    return item?.copyWith(
      checklists: [],
      detail: {},
      completed: false,
      icon: null,
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PlannerCubit, PlannerState>(
    buildWhen: (before, after) =>
        widget.item == null ||
        before.isSaving != after.isSaving ||
        _formEntry(before) != _formEntry(after),
    builder: (context, state) {
      final saving = state.isSaving || _removing;
      final item = widget.item;
      if (item != null) {
        final current =
            state.items.where((entry) => entry.id == item.id).firstOrNull ??
            item;
        return _entryView(current, state, saving);
      }
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
                        ? tr(context, 'Добавить в ежедневник')
                        : tr(context, 'Задача ежедневника'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppFormField(
                    label: tr(context, 'Название'),
                    child: TextField(
                      controller: _title,
                      readOnly:
                          saving ||
                          (item != null && !item.isStandalone) ||
                          _task != null ||
                          _inbox != null,
                      decoration: InputDecoration(
                        hintText: tr(context, 'Введите название'),
                        errorText: trn(context, _validation),
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
                        _picking
                            ? tr(context, 'Загрузка…')
                            : tr(context, 'Из проекта или Инбокса'),
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
                      child: Text(tr(context, 'Создать новую задачу')),
                    ),
                  const SizedBox(height: 12),
                  Material(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF242424)
                        : const Color(0xFFF7F7F7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF3C3C3C)
                            : const Color(0xFFE5E5E5),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: const Key('planner-editor-date'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: const Icon(
                        LucideIcons.calendarDays,
                        size: 19,
                        color: AppColors.accent,
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(context, 'Дата'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _heading(_date),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onTap: saving
                          ? null
                          : () async {
                              final date = await showPlannerDatePicker(
                                context: context,
                                initialDate: _date,
                              );
                              if (date != null && mounted) {
                                setState(() => _date = date);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                  PlannerTimeMode(
                    hasTime: _hasTime,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => _hasTime = value),
                  ),
                  if (_hasTime) ...[
                    const SizedBox(height: 12),
                    PlannerTimeField(
                      key: const Key('planner-editor-time'),
                      time: _time,
                      onChanged: saving
                          ? null
                          : (time) => setState(() => _time = time),
                    ),
                    const SizedBox(height: 16),
                    AppFormField(
                      label: tr(context, 'Длительность'),
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _duration,
                        decoration: InputDecoration(
                          hintText: tr(context, 'Выберите длительность'),
                        ),
                        items:
                            ({15, 30, 45, 60, 90, 120, 180, _duration}.toList()
                                  ..sort())
                                .map(
                                  (minutes) => DropdownMenuItem(
                                    value: minutes,
                                    child: Text(
                                      tr(context, "{p0} мин", {'p0': minutes}),
                                    ),
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
                    child: Text(
                      saving
                          ? tr(context, 'Сохранение…')
                          : tr(context, 'Сохранить'),
                    ),
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
                      child: Text(tr(context, 'Открыть задачу проекта')),
                    ),
                  if (item != null && _removeError != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _removeError!,
                          key: const Key('planner-remove-error'),
                          style: TextStyle(color: AppColors.of(context).error),
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
                        _removing
                            ? tr(context, 'Удаление…')
                            : tr(context, 'Убрать из ежедневника'),
                        style: TextStyle(color: AppColors.of(context).error),
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
