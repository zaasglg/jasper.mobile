import 'package:flutter/material.dart';
import '../../../../core/theme/app_ui_tokens.dart';

Future<void> showTaskDatesSheet(
  BuildContext context, {
  DateTime? start,
  DateTime? end,
  bool selectStart = false,
  bool allowStart = true,
  required Future<bool> Function(DateTime?, DateTime?) onSave,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => TaskDatesSheet(
    start: start,
    end: end,
    selectStart: selectStart,
    allowStart: allowStart,
    onSave: onSave,
  ),
);

class TaskDatesSheet extends StatefulWidget {
  const TaskDatesSheet({
    this.start,
    this.end,
    this.selectStart = false,
    this.allowStart = true,
    required this.onSave,
    super.key,
  });
  final DateTime? start, end;
  final bool selectStart;
  final bool allowStart;
  final Future<bool> Function(DateTime?, DateTime?) onSave;
  @override
  State<TaskDatesSheet> createState() => _TaskDatesSheetState();
}

class _TaskDatesSheetState extends State<TaskDatesSheet> {
  late DateTime? _start = widget.start?.toLocal(), _end = widget.end?.toLocal();
  late bool _startEnabled = widget.allowStart && _start != null;
  late bool _selectStart =
      widget.allowStart && widget.selectStart && _startEnabled;
  bool _busy = false;
  String? _error;
  DateTime? get _selected => _selectStart ? _start : _end;
  late bool _startTime = _hasTime(_start), _endTime = _hasTime(_end);
  bool get _time => _selectStart ? _startTime : _endTime;
  bool _hasTime(DateTime? date) =>
      date != null && (date.hour != 0 || date.minute != 0);
  void _change(DateTime date) => setState(() {
    if (_selectStart) {
      _start = date;
    } else {
      _end = date;
    }
    _error = null;
  });
  Future<void> _pickTime() async {
    final selectStart = _selectStart;
    final date = _selected ?? DateUtils.dateOnly(DateTime.now());
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Выберите время',
      cancelText: 'Отмена',
      confirmText: 'Готово',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (selectStart) {
        _startTime = true;
        _start = value;
      } else {
        _endTime = true;
        _end = value;
      }
      _error = null;
    });
  }

  Future<void> _save({bool clear = false}) async {
    if (_busy) return;
    final start = clear || !_startEnabled ? null : _start;
    final end = clear ? null : _end;
    if (!clear && _startEnabled && start == null) {
      setState(() => _error = 'Выберите дату начала или отключите её.');
      return;
    }
    if (start != null && end != null && start.isAfter(end)) {
      setState(() => _error = 'Начало не может быть позже срока.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.onSave(start, end);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = 'Не удалось сохранить даты. Повторите попытку.';
      });
    }
  }

  String _label(DateTime? date) => date == null
      ? 'Не выбрано'
      : '${MaterialLocalizations.of(context).formatMediumDate(date)}${_hasTime(date) ? ' · ${TimeOfDay.fromDateTime(date).format(context)}' : ''}';
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = _selected ?? DateTime.now();
    final calendar = CalendarDatePicker(
      key: ValueKey(_selectStart),
      initialDate: date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      onDateChanged: _busy
          ? (_) {}
          : (day) => _change(
              DateTime(
                day.year,
                day.month,
                day.day,
                _time ? date.hour : 0,
                _time ? date.minute : 0,
              ),
            ),
    );
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Даты', style: AppTypography.title(context)),
                    ),
                    IconButton(
                      tooltip: 'Закрыть даты',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        if (widget.allowStart) ...[
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.smMd,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            tileColor: colors.surfaceContainerLow,
                            title: const Text('Начало'),
                            subtitle: Text(
                              _startEnabled ? 'Включена' : 'Необязательно',
                            ),
                            value: _startEnabled,
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    _startEnabled = value;
                                    _selectStart = value;
                                    _error = null;
                                  }),
                          ),
                          const SizedBox(height: AppSpacing.smMd),
                        ],
                        Row(
                          children: [
                            if (_startEnabled) ...[
                              Expanded(
                                child: _DateChoice(
                                  title: 'НАЧАЛО',
                                  value: _label(_start),
                                  active: _selectStart,
                                  onTap: _busy
                                      ? null
                                      : () =>
                                            setState(() => _selectStart = true),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: _DateChoice(
                                title: 'СРОК',
                                value: _label(_end),
                                active: !_selectStart,
                                onTap: _busy
                                    ? null
                                    : () =>
                                          setState(() => _selectStart = false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.smMd),
                        calendar,
                        const SizedBox(height: AppSpacing.sm),
                        _TimeChoice(
                          enabled: _time,
                          value: MaterialLocalizations.of(context)
                              .formatTimeOfDay(
                                TimeOfDay.fromDateTime(date),
                                alwaysUse24HourFormat: true,
                              ),
                          onEdit: _busy ? null : _pickTime,
                          onChanged: _busy
                              ? null
                              : (enabled) {
                                  if (enabled) {
                                    _pickTime();
                                    return;
                                  }
                                  setState(() {
                                    if (_selectStart) {
                                      _startTime = false;
                                    } else {
                                      _endTime = false;
                                    }
                                  });
                                  if (_selected != null) {
                                    _change(DateUtils.dateOnly(date));
                                  }
                                },
                        ),
                        if (_error != null)
                          Text(_error!, style: TextStyle(color: colors.error)),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _save(clear: true),
                        child: const Text('Очистить'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Сохранение…' : 'Сохранить'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.title,
    required this.value,
    required this.active,
    required this.onTap,
  });
  final String title, value;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: active ? colors.primaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: active ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.smMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.caption(context)?.copyWith(
                  color: active ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.body(
                  context,
                )?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChoice extends StatelessWidget {
  const _TimeChoice({
    required this.enabled,
    required this.value,
    required this.onEdit,
    required this.onChanged,
  });

  final bool enabled;
  final String value;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.smMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_outlined),
                const SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: Text('Время', style: AppTypography.body(context)),
                ),
                Semantics(
                  label: 'Указать время',
                  child: Switch(
                    key: const Key('task_time_toggle'),
                    value: enabled,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
            if (enabled)
              OutlinedButton.icon(
                key: const Key('task_time_edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text('$value · Изменить'),
              )
            else
              Text('Только дата', style: AppTypography.caption(context)),
          ],
        ),
      ),
    );
  }
}
