import 'package:flutter/material.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/models/task_detail_model.dart';
import '../cubit/task_details_cubit.dart';

Future<void> showServerResourceCalculator(
  BuildContext context,
  TaskDetailsCubit cubit,
  String id,
  String target,
  double current,
) => showDialog<void>(
  context: context,
  builder: (_) =>
      _Calculator(cubit: cubit, id: id, target: target, current: current),
);

class _Calculator extends StatefulWidget {
  const _Calculator({
    required this.cubit,
    required this.id,
    required this.target,
    required this.current,
  });
  final TaskDetailsCubit cubit;
  final String id, target;
  final double current;
  @override
  State<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<_Calculator> {
  final _input = TextEditingController();
  String _operation = 'ADD';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_busy) return;
    final text = _input.text.trim().replaceAll(',', '.');
    if (!RegExp(r'^-?\d+(?:\.\d{1,4})?$').hasMatch(text) ||
        !((double.tryParse(text))?.isFinite ?? false)) {
      setState(() => _error = 'Введите число, до 4 знаков после запятой');
      return;
    }
    if (_operation == 'DIVIDE' && double.parse(text) == 0) {
      setState(() => _error = 'Нельзя делить на ноль');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.cubit.patchResource(widget.id, {
      'calculation': {
        'target': widget.target,
        'operation': _operation,
        'value': text,
      },
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = widget.cubit.state.actionErrorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Калькулятор'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Текущее значение: ${widget.current}'),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'ADD', label: Text('+')),
                ButtonSegment(value: 'SUBTRACT', label: Text('−')),
                ButtonSegment(value: 'MULTIPLY', label: Text('×')),
                ButtonSegment(value: 'DIVIDE', label: Text('÷')),
              ],
              selected: {_operation},
              onSelectionChanged: _busy
                  ? null
                  : (v) => setState(() => _operation = v.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _input,
              enabled: !_busy,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                hintText: 'Введите число',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _apply,
          child: Text(_busy ? 'Сохранение…' : 'Применить'),
        ),
      ],
    ),
  );
}

Future<void> showResourceHistory(
  BuildContext context,
  TaskDetailsCubit cubit,
  String id,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _History(cubit: cubit, id: id),
);

Future<void> showResourcePairHistory(
  BuildContext context,
  TaskDetailsCubit cubit,
  List<TaskResourceModel> resources,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _PairHistoryBody(cubit: cubit, resources: resources),
);

List<List<Map<String, Object?>?>> alignResourceHistories(
  List<List<Map<String, Object?>>> histories,
) {
  final buckets = <int, List<List<Map<String, Object?>>>>{};
  for (var column = 0; column < histories.length; column++) {
    for (final item in histories[column]) {
      final time =
          DateTime.tryParse(
            item['createdAt']?.toString() ?? '',
          )?.millisecondsSinceEpoch ??
          0;
      final columns = buckets.putIfAbsent(
        time ~/ 60000,
        () => List.generate(histories.length, (_) => []),
      );
      columns[column].add(item);
    }
  }
  final rows = <List<Map<String, Object?>?>>[];
  for (final minute in buckets.keys.toList()..sort()) {
    final columns = buckets[minute]!;
    var count = 0;
    for (final column in columns) {
      column.sort((a, b) {
        final comparison =
            (DateTime.tryParse(
                      a['createdAt']?.toString() ?? '',
                    )?.millisecondsSinceEpoch ??
                    0)
                .compareTo(
                  DateTime.tryParse(
                        b['createdAt']?.toString() ?? '',
                      )?.millisecondsSinceEpoch ??
                      0,
                );
        return comparison != 0
            ? comparison
            : (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
      });
      if (column.length > count) count = column.length;
    }
    for (var index = 0; index < count; index++) {
      rows.add([
        for (final column in columns)
          index < column.length ? column[index] : null,
      ]);
    }
  }
  return rows;
}

class _PairHistoryBody extends StatefulWidget {
  const _PairHistoryBody({required this.cubit, required this.resources});
  final TaskDetailsCubit cubit;
  final List<TaskResourceModel> resources;
  @override
  State<_PairHistoryBody> createState() => _PairHistoryBodyState();
}

class _PairHistoryBodyState extends State<_PairHistoryBody> {
  late final _histories = List.generate(
    widget.resources.length,
    (_) => <Map<String, Object?>>[],
  );
  late final _cursors = List<String?>.filled(widget.resources.length, null);
  bool _busy = true, _loaded = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Commit the whole batch together so retry cannot duplicate one side.
      final pages = await Future.wait([
        for (var i = 0; i < widget.resources.length; i++)
          if (!_loaded || _cursors[i] != null)
            widget.cubit.resourceHistory(
              widget.resources[i].id,
              cursor: _cursors[i],
            )
          else
            Future.value(<String, Object?>{
              'items': <Object?>[],
              'nextCursor': null,
            }),
      ]);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < pages.length; i++) {
          final items = pages[i]['items'];
          if (items is List) {
            _histories[i].addAll(
              items.whereType<Map>().map((v) => Map<String, Object?>.from(v)),
            );
          }
          _cursors[i] = pages[i]['nextCursor'] as String?;
        }
        _busy = false;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось загрузить историю';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = alignResourceHistories(_histories);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'История ресурсов',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть историю',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width:
                        (constraints.maxWidth / widget.resources.length).clamp(
                          320.0,
                          double.infinity,
                        ) *
                        widget.resources.length,
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var column = 0;
                            column < widget.resources.length;
                            column++
                          )
                            Expanded(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: Text(
                                        widget.resources[column].name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  _ResourceHistoryTable(
                                    items: [
                                      for (final row in rows) row[column],
                                    ],
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
            ),
            if (_busy) const LinearProgressIndicator(),
            if (!_busy && rows.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('История пока пуста'),
              ),
            if (_error != null) Text(_error!),
            if (!_busy && (_error != null || _cursors.any((v) => v != null)))
              TextButton(
                onPressed: _load,
                child: Text(_error != null ? 'Повторить' : 'Загрузить ещё'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResourceHistoryTable extends StatelessWidget {
  const _ResourceHistoryTable({required this.items});
  final List<Map<String, Object?>?> items;
  String _value(Object? value) {
    final number = double.tryParse(value?.toString() ?? '');
    if (number == null) return '—';
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }

  String _date(Object? value) {
    final date = DateTime.tryParse(
      value?.toString() ?? '',
    )?.toUtc().add(const Duration(hours: 5));
    if (date == null) return '—';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(date.day)}.${pad(date.month)}.${date.year}\n${pad(date.hour)}:${pad(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FixedColumnWidth(64),
        2: FixedColumnWidth(112),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(color: colors.outlineVariant),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.surfaceContainerLow),
          children: [
            for (final label in ['Изменение', 'Автор', 'Дата'])
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        for (final item in items)
          if (item == null)
            TableRow(
              children: [
                SizedBox(height: MediaQuery.textScalerOf(context).scale(64)),
                const SizedBox(),
                const SizedBox(),
              ],
            )
          else
            TableRow(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.textScalerOf(context).scale(64),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '${_value(item['previousValue'])} → ${_value(item['newValue'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Tooltip(
                      message: item['user'] is Map
                          ? (item['user'] as Map)['name']?.toString() ?? 'Автор'
                          : 'Автор',
                      child: UserAvatar(
                        size: 28,
                        name: item['user'] is Map
                            ? (item['user'] as Map)['name']?.toString() ?? ''
                            : '',
                        avatarUrl: item['user'] is Map
                            ? (item['user'] as Map)['avatarUrl']?.toString()
                            : null,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _date(item['createdAt']),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

class _History extends StatefulWidget {
  const _History({required this.cubit, required this.id});
  final TaskDetailsCubit cubit;
  final String id;
  final bool showTitle = true;
  final bool table = false;
  final String? target = null;
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  final _items = <Map<String, Object?>>[];
  String? _cursor, _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.cubit.resourceHistory(
        widget.id,
        cursor: _cursor,
      );
      if (!mounted) return;
      final items = page['items'];
      setState(() {
        if (items is List) {
          _items.addAll(
            items
                .whereType<Map>()
                .where(
                  (v) => widget.target == null || v['target'] == widget.target,
                )
                .map((v) => Map<String, Object?>.from(v)),
          );
        }
        _cursor = page['nextCursor'] as String?;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось загрузить историю';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListView(
        padding: widget.table ? EdgeInsets.zero : const EdgeInsets.all(16),
        children: [
          if (widget.showTitle)
            Text(
              'История ресурса',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          if (widget.table) _ResourceHistoryTable(items: _items),
          if (!widget.table)
            for (final item in _items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item['formattedLog']?.toString() ??
                      '${item['previousValue']} → ${item['newValue']}',
                ),
                subtitle: Text(
                  [
                    if (item['user'] case final Map user)
                      user['name']?.toString() ?? '',
                    item['createdAt']?.toString() ?? '',
                  ].where((v) => v.isNotEmpty).join(' · '),
                ),
              ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (!_busy && _error == null && _items.isEmpty)
            const Text('История пока пуста'),
          if (_error != null) Text(_error!),
          if (!_busy && (_cursor != null || _error != null))
            TextButton(
              onPressed: _load,
              child: Text(_error != null ? 'Повторить' : 'Загрузить ещё'),
            ),
        ],
      ),
    ),
  );
}
