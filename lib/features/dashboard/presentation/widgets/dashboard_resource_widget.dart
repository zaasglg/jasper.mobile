import '../utils/dashboard_options_changes.dart';
import '../../domain/entities/dashboard_widget_options.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_widget_heading.dart';
import 'dashboard_selector.dart';
import 'dashboard_expandable_content.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../projects/data/models/project_model.dart';
import 'dashboard_task_list_sheet.dart';
import 'dashboard_widget_panel.dart'
    show dashboardObject, flattenDashboardProjects;

typedef ResourcePair = ({
  String id,
  String planName,
  String factName,
  double plan,
  double fact,
  Map<String, dynamic>? task,
});

class DashboardResourceWidget extends StatefulWidget {
  const DashboardResourceWidget({
    super.key,
    required this.tasks,
    required this.projects,
    required this.options,
    required this.onChanged,
    required this.onOpenTask,
    this.size = 'half',
    this.trailing,
  });
  final List<Map<String, dynamic>> tasks;
  final List<ProjectModel> projects;
  final DashboardWidgetOptions options;
  final String size;
  final Widget? trailing;
  final Future<bool> Function(Map<String, dynamic>) onChanged;
  final Future<void> Function(String) onOpenTask;
  @override
  State<DashboardResourceWidget> createState() =>
      _DashboardResourceWidgetState();
}

class ResourceEmptyState extends StatelessWidget {
  const ResourceEmptyState({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              LucideIcons.archive,
              size: AppSpacing.lg,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title(context)?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                context,
              )?.copyWith(color: AppColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardResourceWidgetState extends State<DashboardResourceWidget> {
  late DashboardWidgetOptions _options = widget.options;
  bool _saving = false;
  String get _projectId => _options.resourceProjectId?.toString() ?? 'all';
  String get _filter => _options.resourceFilterType?.toString() ?? 'projects';
  String get _mode =>
      dashboardObject(_options.resourceModeByProject)[_projectId]?.toString() ??
      'all';
  int get _limit => widget.size == 'full'
      ? 12
      : widget.size == 'third'
      ? 6
      : 8;
  Set<String> _set(dynamic value) =>
      value is List ? value.map((e) => e.toString()).toSet() : {};
  Set<String> get _names => _set(
    dashboardObject(_options.resourceNamesByProject)[_projectId] ??
        _options.resourceNames,
  );
  @override
  void didUpdateWidget(covariant DashboardResourceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options && !_saving) {
      _options = widget.options;
    }
  }

  Future<void> _apply(Map<String, dynamic> patch) async {
    if (_saving) return;
    final previous = _options;
    setState(() {
      _saving = true;
      _options = patchDashboardOptions(_options, patch);
    });
    final success = await widget.onChanged(patch);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!success) _options = previous;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.error,
          content: Text('Не удалось сохранить настройки ресурса'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> task) {
    final list = (task['resources'] as List? ?? [])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final indexed = [
      for (var i = 0; i < list.length; i++)
        {
          ...list[i],
          'order':
              double.tryParse(list[i]['order']?.toString() ?? '') ??
              i.toDouble(),
        },
    ];
    indexed.sort(
      (a, b) => (a['order'] as double).compareTo(b['order'] as double),
    );
    return indexed;
  }

  double _number(dynamic value) {
    final result = double.tryParse(value?.toString() ?? '') ?? 0;
    return result.isFinite ? result : 0;
  }

  List<ResourcePair> _pairs(
    Map<String, dynamic> task, {
    bool completeOnly = false,
  }) {
    final rows = _rows(task);
    return [
      for (var i = 0; i < rows.length; i += 2)
        if (!completeOnly || i + 1 < rows.length)
          (
            id: jsonEncode([
              rows[i]['name']?.toString().trim().isNotEmpty == true
                  ? rows[i]['name'].toString().trim()
                  : 'План',
              i + 1 < rows.length &&
                      rows[i + 1]['name']?.toString().trim().isNotEmpty == true
                  ? rows[i + 1]['name'].toString().trim()
                  : 'Факт',
            ]),
            planName: rows[i]['name']?.toString().trim().isNotEmpty == true
                ? rows[i]['name'].toString().trim()
                : 'План',
            factName:
                i + 1 < rows.length &&
                    rows[i + 1]['name']?.toString().trim().isNotEmpty == true
                ? rows[i + 1]['name'].toString().trim()
                : 'Факт',
            plan: _number(rows[i]['planValue']),
            fact: i + 1 < rows.length ? _number(rows[i + 1]['factValue']) : 0.0,
            task: task,
          ),
    ];
  }

  Map<String, String> get _labels {
    final result = <String, String>{};
    for (final task in widget.tasks) {
      for (final raw
          in dashboardObject(task['detail'])['labels'] as List? ?? []) {
        final label = dashboardObject(raw);
        final text = label['text']?.toString().trim() ?? '';
        final color = label['color']?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          result[jsonEncode([text.toLowerCase(), color])] = text;
        }
      }
    }
    return result;
  }

  Map<String, String> get _epics {
    final result = <String, String>{};
    for (final task in widget.tasks) {
      for (final raw in task['epics'] as List? ?? []) {
        final relation = dashboardObject(raw);
        final epic = dashboardObject(relation['epic'] ?? relation);
        final id = (relation['epicId'] ?? epic['id'])?.toString();
        final name = epic['name']?.toString();
        if (id != null && name != null) result[id] = name;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _tasks {
    final projects = flattenDashboardProjects(widget.projects);
    final selected = projects.where((p) => p.id == _projectId).firstOrNull;
    final scope = selected == null
        ? null
        : flattenDashboardProjects([selected]).map((p) => p.id).toSet();
    final available = _filter == 'labels' ? _labels : _epics;
    final values = _set(
      (_filter == 'labels'
          ? _options.resourceLabelKeys
          : _options.resourceEpicIds),
    ).intersection(available.keys.toSet());
    return widget.tasks.where((task) {
      if (task['archived'] == true) return false;
      if (_filter == 'projects') {
        return scope == null || scope.contains(task['projectId']);
      }
      if (values.isEmpty) return true;
      if (_filter == 'labels') {
        return (dashboardObject(task['detail'])['labels'] as List? ?? []).any((
          raw,
        ) {
          final label = dashboardObject(raw);
          return values.contains(
            jsonEncode([
              label['text']?.toString().trim().toLowerCase() ?? '',
              label['color']?.toString().trim() ?? '',
            ]),
          );
        });
      }
      return (task['epics'] as List? ?? []).any((e) {
        final relation = dashboardObject(e);
        return values.contains(
          (relation['epicId'] ?? dashboardObject(relation['epic'])['id'])
              ?.toString(),
        );
      });
    }).toList();
  }

  List<ResourcePair> _metrics(List<Map<String, dynamic>> tasks) {
    final result = <String, ResourcePair>{};
    for (final task in tasks) {
      for (final pair in _pairs(task, completeOnly: true)) {
        final old = result[pair.id];
        result[pair.id] = (
          id: pair.id,
          planName: pair.planName,
          factName: pair.factName,
          plan: (old?.plan ?? 0) + pair.plan,
          fact: (old?.fact ?? 0) + pair.fact,
          task: null,
        );
      }
    }
    return result.values.toList();
  }

  Future<void> _metricsPicker(List<ResourcePair> metrics) async {
    var mode = _mode;
    var selected = _names.intersection(metrics.map((m) => m.id).toSet());
    final result =
        await showModalBottomSheet<({String mode, List<String> names})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: Colors.white,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheet) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Метрики',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: const Text('Все метрики'),
                              value: mode == 'all',
                              onChanged: (value) => setSheet(() {
                                mode = value == true ? 'all' : 'tasks';
                                selected = {};
                              }),
                            ),
                            const Divider(height: 1),
                            if (metrics.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('Нет пар ресурсов'),
                              ),
                            for (final metric in metrics)
                              CheckboxListTile(
                                title: Text(
                                  '${metric.planName} / ${metric.factName}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                value:
                                    mode == 'all' ||
                                    selected.contains(metric.id),
                                onChanged:
                                    mode == 'selected' &&
                                        !selected.contains(metric.id) &&
                                        selected.length >= _limit
                                    ? null
                                    : (value) => setSheet(() {
                                        if (mode == 'all') {
                                          selected = metrics
                                              .map((m) => m.id)
                                              .toSet();
                                        }
                                        value == true
                                            ? selected.add(metric.id)
                                            : selected.remove(metric.id);
                                        mode = selected.isEmpty
                                            ? 'tasks'
                                            : 'selected';
                                      }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, (
                        mode: mode,
                        names: selected.toList(),
                      )),
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    if (result == null || !mounted) return;
    await _apply({
      'resourceModeByProject': {
        ...dashboardObject(_options.resourceModeByProject),
        _projectId: result.mode,
      },
      'resourceNamesByProject': {
        ...dashboardObject(_options.resourceNamesByProject),
        _projectId: result.names,
      },
    });
  }

  Future<void> _selectionPicker() async {
    final available = _filter == 'labels' ? _labels : _epics;
    final key = _filter == 'labels' ? 'resourceLabelKeys' : 'resourceEpicIds';
    final selected = _set(
      (key == 'resourceLabelKeys'
          ? _options.resourceLabelKeys
          : _options.resourceEpicIds),
    ).intersection(available.keys.toSet());
    final entries = available.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _filter == 'labels' ? 'Метки' : 'Эпики',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: Text(
                            _filter == 'labels' ? 'Все метки' : 'Все эпики',
                          ),
                          value: selected.isEmpty,
                          onChanged: (_) => setSheet(selected.clear),
                        ),
                        for (final entry in entries)
                          CheckboxListTile(
                            title: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 13),
                            ),
                            value: selected.contains(entry.key),
                            onChanged: (v) => setSheet(
                              () => v == true
                                  ? selected.add(entry.key)
                                  : selected.remove(entry.key),
                            ),
                          ),
                        if (entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Нет доступных значений'),
                          ),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected.toList()),
                  child: const Text('Готово'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) await _apply({key: result});
  }

  String _compact(double value) {
    final abs = value.abs();
    final divisor = abs >= 1e9
        ? 1e9
        : abs >= 1e6
        ? 1e6
        : abs >= 1e3
        ? 1e3
        : 1;
    final n = value / divisor;
    final text = n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(1).replaceAll('.', ',');
    return '$text${divisor == 1e9
        ? ' млрд'
        : divisor == 1e6
        ? ' млн'
        : divisor == 1e3
        ? ' тыс.'
        : ''}';
  }

  Widget _legend(String name, double value, Color color) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Tooltip(
          message: name,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        _compact(value),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    ],
  );
  Future<void> _open(
    ResourcePair pair,
    List<Map<String, dynamic>> tasks,
  ) async {
    if (pair.task != null) {
      final id = pair.task!['id']?.toString();
      if (id != null) await widget.onOpenTask(id);
      return;
    }
    final matching = tasks
        .where((t) => _pairs(t, completeOnly: true).any((p) => p.id == pair.id))
        .toList();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => DashboardTaskListSheet(
        title: '${pair.planName} / ${pair.factName}',
        tasks: matching,
        projects: widget.projects,
      ),
    );
    if (id != null && mounted) await widget.onOpenTask(id);
  }

  Future<void> _reorder(
    String from,
    String to,
    List<ResourcePair> metrics,
  ) async {
    final valid = _names.intersection(metrics.map((m) => m.id).toSet());
    final ids = _mode == 'all'
        ? metrics.map((m) => m.id).toList()
        : valid.toList();
    final oldIndex = ids.indexOf(from), newIndex = ids.indexOf(to);
    if (oldIndex < 0 || newIndex < 0 || oldIndex == newIndex) return;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    await _apply({
      'resourceModeByProject': {
        ...dashboardObject(_options.resourceModeByProject),
        _projectId: 'selected',
      },
      'resourceNamesByProject': {
        ...dashboardObject(_options.resourceNamesByProject),
        _projectId: ids,
      },
    });
  }

  Widget _ring(ResourcePair pair, int index, List<Map<String, dynamic>> tasks) {
    const accent = Color(0xFF6D5FE0),
        blue = Color(0xFF3B82C4),
        green = Color(0xFF1A7048),
        brown = Color(0xFF8A5520),
        red = Color(0xFFB52B1D);
    Color mix(Color a, Color b, double weight) => Color.lerp(a, b, weight)!;
    final colors = [
      (accent, mix(accent, blue, .4)),
      (blue, mix(blue, accent, .35)),
      (green, mix(green, blue, .35)),
      (brown, mix(brown, red, .35)),
      (red, mix(red, accent, .35)),
      (mix(blue, green, .45), mix(blue, green, .7)),
      (mix(accent, green, .4), mix(accent, green, .65)),
      (mix(blue, brown, .4), mix(blue, brown, .65)),
      (mix(green, red, .4), mix(green, red, .65)),
      (mix(brown, accent, .4), mix(brown, accent, .65)),
    ];
    final (planColor, factColor) = colors[index % colors.length];
    final ratio = pair.plan <= 0
        ? 0.0
        : (pair.fact / pair.plan).clamp(0.0, 1.0);
    final rawPercent = pair.plan <= 0 ? 0.0 : pair.fact / pair.plan * 100;
    final percent = rawPercent.isNaN || rawPercent < 0
        ? 0
        : rawPercent > 999
        ? 1000
        : rawPercent.round();
    final title = pair.task == null
        ? '${pair.planName} / ${pair.factName}'
        : [
            pair.task!['displayId'],
            pair.task!['title'],
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => _open(pair, tasks),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Column(
          children: [
            SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      color: factColor,
                      backgroundColor: planColor.withValues(alpha: .24),
                    ),
                  ),
                  Text(
                    percent > 999 ? '999%+' : '$percent%',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _legend(pair.planName, pair.plan, planColor),
            const SizedBox(height: 5),
            _legend(pair.factName, pair.fact, factColor),
          ],
        ),
      ),
    );
  }

  Widget _trigger(String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ),
      const SizedBox(width: 3),
      const Icon(LucideIcons.chevronDown, size: 12, color: AppColors.muted),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final metrics = _metrics(tasks);
    final validNames = _names.intersection(metrics.map((m) => m.id).toSet());
    final sorted = [...tasks]
      ..sort((a, b) {
        final date =
            (DateTime.tryParse(a['end']?.toString() ?? '') ?? DateTime(9999))
                .compareTo(
                  DateTime.tryParse(b['end']?.toString() ?? '') ??
                      DateTime(9999),
                );
        return date != 0
            ? date
            : (a['title']?.toString().toLowerCase() ?? '').compareTo(
                b['title']?.toString().toLowerCase() ?? '',
              );
      });
    final allItems = _mode == 'tasks'
        ? [for (final task in sorted) ..._pairs(task)]
        : (_mode == 'all'
                  ? metrics
                  : [
                      for (final id in validNames)
                        ...metrics.where((m) => m.id == id),
                    ])
              .take(_limit)
              .toList();
    final items = DashboardPreviewScope.limit(context, allItems);
    final project = flattenDashboardProjects(
      widget.projects,
    ).where((p) => p.id == _projectId).firstOrNull;
    final selectedLabelCount = _set(
      (_filter == 'labels'
          ? _options.resourceLabelKeys
          : _options.resourceEpicIds),
    ).length;
    final selectionLabel = _filter == 'projects'
        ? project?.name ?? 'Все проекты'
        : _filter == 'labels'
        ? (selectedLabelCount == 0 ? 'Все метки' : 'Метки: $selectedLabelCount')
        : (selectedLabelCount == 0
              ? 'Все эпики'
              : 'Эпики: $selectedLabelCount');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AppWidgetHeading(
              icon: LucideIcons.chartNoAxesCombined,
              title: 'Ресурс',
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _filter == 'projects'
                  ? DashboardSelector<String>(
                      enabled: !_saving,
                      tooltip: 'Проект ресурса',
                      onSelected: (id) => _apply({'resourceProjectId': id}),
                      itemBuilder: (_) => [
                        CheckedPopupMenuItem(
                          value: 'all',
                          checked: project == null,
                          child: const Text('Все проекты'),
                        ),
                        for (final p in flattenDashboardProjects(
                          widget.projects,
                        ))
                          CheckedPopupMenuItem(
                            value: p.id,
                            checked: p.id == _projectId,
                            child: Text(p.name),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _trigger(selectionLabel),
                      ),
                    )
                  : InkWell(
                      onTap: _saving ? null : _selectionPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _trigger(selectionLabel),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _saving ? null : () => _metricsPicker(metrics),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _trigger('Метрики'),
              ),
            ),
            const SizedBox(width: 9),
            DashboardSelector<String>(
              enabled: !_saving,
              tooltip: 'Отбор ресурсов',
              onSelected: (filter) => _apply({'resourceFilterType': filter}),
              itemBuilder: (_) => [
                for (final entry in {
                  'projects': 'Проекты',
                  'labels': 'Метки',
                  'epics': 'Эпики',
                }.entries)
                  CheckedPopupMenuItem(
                    value: entry.key,
                    checked: _filter == entry.key,
                    child: Text(entry.value),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _trigger(
                  {
                        'projects': 'Проекты',
                        'labels': 'Метки',
                        'epics': 'Эпики',
                      }[_filter] ??
                      'Проекты',
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
        const Divider(height: AppSpacing.xxs, color: AppColors.border),
        if (items.isEmpty)
          ResourceEmptyState(
            title: _mode == 'tasks'
                ? 'Нет задач с ресурсами'
                : 'Нет данных ресурса',
            description: _projectId == 'all'
                ? 'Выберите проект или измените фильтры, чтобы увидеть данные.'
                : 'В выбранном проекте пока нет данных для этих метрик.',
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 150).floor().clamp(2, 6);
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    width: width,
                    child: _mode == 'tasks'
                        ? _ring(items[i], i, tasks)
                        : DragTarget<String>(
                            onWillAcceptWithDetails: (details) =>
                                !_saving && details.data != items[i].id,
                            onAcceptWithDetails: (details) =>
                                _reorder(details.data, items[i].id, metrics),
                            builder: (context, candidates, rejected) =>
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: candidates.isEmpty
                                        ? Colors.transparent
                                        : AppColors.accent.withValues(
                                            alpha: .06,
                                          ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: LongPressDraggable<String>(
                                    data: items[i].id,
                                    maxSimultaneousDrags: _saving ? 0 : 1,
                                    feedback: Material(
                                      color: Colors.white,
                                      elevation: 2,
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: width,
                                        child: _ring(items[i], i, tasks),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: .3,
                                      child: _ring(items[i], i, tasks),
                                    ),
                                    child: _ring(items[i], i, tasks),
                                  ),
                                ),
                          ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
