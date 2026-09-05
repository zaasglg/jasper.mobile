import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/screens/main_shell.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Открыть меню',
          onPressed: MainShell.openDrawer,
          icon: const Icon(Icons.menu_rounded, color: AppColors.ink),
        ),
        title: Text(
          'Ежедневник',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Сегодня',
            key: const Key('planner-today'),
            onPressed: _selectToday,
            icon: const Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _PlannerToolbar(
              selectedDate: _selectedDate,
              onPickDate: _pickDate,
              onPreviousDay: () => _moveByDays(-1),
              onToday: _selectToday,
              onNextDay: () => _moveByDays(1),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: _handleHorizontalDrag,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _PlannerDay(
                    key: ValueKey<DateTime>(_selectedDate),
                    selectedDate: _selectedDate,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (picked != null) _selectDate(picked);
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = _dateOnly(date));
  }

  void _selectToday() => _selectDate(DateTime.now());

  void _moveByDays(int days) {
    _selectDate(_selectedDate.add(Duration(days: days)));
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 180) return;
    _moveByDays(velocity < 0 ? 1 : -1);
  }
}

class _PlannerToolbar extends StatelessWidget {
  const _PlannerToolbar({
    required this.selectedDate,
    required this.onPickDate,
    required this.onPreviousDay,
    required this.onToday,
    required this.onNextDay,
  });

  final DateTime selectedDate;
  final VoidCallback onPickDate;
  final VoidCallback onPreviousDay;
  final VoidCallback onToday;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                key: const Key('planner-date-picker'),
                borderRadius: BorderRadius.circular(8),
                onTap: onPickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _monthNames[selectedDate.month - 1],
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _ToolbarButton(
            key: const Key('planner-previous-day'),
            tooltip: 'Предыдущий день',
            onPressed: onPreviousDay,
            icon: Icons.chevron_left_rounded,
          ),
          const SizedBox(width: 5),
          _TodayButton(onPressed: onToday),
          const SizedBox(width: 5),
          _ToolbarButton(
            key: const Key('planner-next-day'),
            tooltip: 'Следующий день',
            onPressed: onNextDay,
            icon: Icons.chevron_right_rounded,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Text('Сегодня'),
      ),
    );
  }
}

class _PlannerDay extends StatelessWidget {
  const _PlannerDay({super.key, required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Text(
            _formatDayHeading(selectedDate),
            key: const Key('planner-selected-date'),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        const _DueCardsLane(),
        Expanded(child: _DayTimeline(selectedDate: selectedDate)),
      ],
    );
  }
}

class _DueCardsLane extends StatelessWidget {
  const _DueCardsLane();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: _DayTimeline.timeColumnWidth,
            child: Center(
              child: Text(
                'GMT+5',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Нет задач со сроком',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.muted,
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
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.selectedDate});

  final DateTime selectedDate;

  static const double timeColumnWidth = 57;
  static const double hourHeight = 64;
  static const int firstHour = 8;
  static const int lastHour = 20;

  @override
  Widget build(BuildContext context) {
    final hours = List<int>.generate(
      lastHour - firstHour + 1,
      (index) => firstHour + index,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Stack(
        children: <Widget>[
          Column(children: hours.map((hour) => _HourRow(hour: hour)).toList()),
          if (_isSameDay(selectedDate, DateTime.now()))
            const _CurrentTimeMarker(),
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _DayTimeline.hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _DayTimeline.timeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                hour.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 13),
              child: Divider(height: 1, color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentTimeMarker extends StatelessWidget {
  const _CurrentTimeMarker();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final minutesFromStart =
        (now.hour - _DayTimeline.firstHour) * 60 + now.minute;
    final top =
        minutesFromStart.clamp(
          0,
          (_DayTimeline.lastHour - _DayTimeline.firstHour + 1) * 60,
        ) /
        60 *
        _DayTimeline.hourHeight;

    return Positioned(
      top: top,
      left: _DayTimeline.timeColumnWidth - 3,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
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
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _formatDayHeading(DateTime date) {
  final weekday = _weekdayNames[date.weekday - 1];
  return '$weekday, ${date.day} ${_genitiveMonthNames[date.month - 1]}';
}

const List<String> _weekdayNames = <String>[
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const List<String> _monthNames = <String>[
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

const List<String> _genitiveMonthNames = <String>[
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
