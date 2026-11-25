import 'package:jospar/core/localization/app_translations.dart';
import '../../../projects/domain/entities/project_model.dart';
import '../../domain/entities/dashboard_widget_options.dart';
import 'dart:convert';
import 'dashboard_widget_skeleton.dart';
import 'dashboard_selector.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/dashboard_layout_cubit.dart';
import 'dashboard_widget_panel.dart';

class DashboardResourceOptions extends StatefulWidget {
  const DashboardResourceOptions({
    required this.cubit,
    required this.projects,
    required this.projectId,
    required this.options,
    required this.onChanged,
    super.key,
  });
  final DashboardLayoutCubit cubit;
  final List<ProjectModel> projects;
  final String projectId;
  final DashboardWidgetOptions options;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  State<DashboardResourceOptions> createState() =>
      _DashboardResourceOptionsState();
}

class _DashboardResourceOptionsState extends State<DashboardResourceOptions> {
  late String _filter, _mode;
  late Set<String> _labels, _epics, _names;
  late Future<dynamic> _future;
  late Map<String, dynamic> _modes, _namesByProject;
  Set<String> _set(dynamic value) =>
      value is List ? value.map((e) => e.toString()).toSet() : {};
  @override
  void initState() {
    super.initState();
    _filter =
        [
          'projects',
          'labels',
          'epics',
        ].contains(widget.options.resourceFilterType)
        ? widget.options.resourceFilterType as String
        : 'projects';
    _labels = _set(widget.options.resourceLabelKeys);
    _epics = _set(widget.options.resourceEpicIds);
    _modes = dashboardObject(widget.options.resourceModeByProject);
    _namesByProject = dashboardObject(widget.options.resourceNamesByProject);
    _projectOptions();
    _load();
  }

  @override
  void didUpdateWidget(DashboardResourceOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) _projectOptions();
  }

  void _projectOptions() {
    final mode = _modes[widget.projectId];
    _mode = ['all', 'selected', 'tasks'].contains(mode)
        ? mode as String
        : 'all';
    _names = _set(
      _namesByProject[widget.projectId] ?? widget.options.resourceNames,
    );
    _notify();
  }

  String get _key {
    final ids = flattenDashboardProjects(
      widget.projects,
    ).map((e) => e.id).toList()..sort();
    return 'tasks:${ids.join(',')}';
  }

  void _load() {
    final ids = flattenDashboardProjects(
      widget.projects,
    ).map((e) => e.id).toList()..sort();
    final workspace = widget.cubit.state.workspaceId;
    _future = widget.cubit.data(
      _key,
      () => widget.cubit.repository.tasks(workspace, ids),
    );
  }

  void _notify() {
    _modes[widget.projectId] = _mode;
    _namesByProject[widget.projectId] = _names.toList();
    widget.onChanged({
      'resourceFilterType': _filter,
      'resourceLabelKeys': _labels.toList(),
      'resourceEpicIds': _epics.toList(),
      'resourceModeByProject': {..._modes},
      'resourceNamesByProject': {..._namesByProject},
    });
  }

  Widget _choices(
    Map<String, String> available,
    Set<String> values,
    String all,
    String empty,
  ) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: identical(values, _names) ? _mode == 'all' : values.isEmpty,
        title: Text(all, style: const TextStyle(fontSize: 13)),
        onChanged: (_) => setState(() {
          values.clear();
          if (identical(values, _names)) _mode = 'all';
          _notify();
        }),
      ),
      if (available.isEmpty)
        Text(
          empty,
          style: TextStyle(fontSize: 12, color: AppColors.of(context).muted),
        ),
      for (final item in available.entries)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: values.contains(item.key),
          title: Text(item.value, style: const TextStyle(fontSize: 13)),
          onChanged: (value) => setState(() {
            value == true ? values.add(item.key) : values.remove(item.key);
            if (identical(values, _names)) {
              _mode = values.isEmpty ? 'tasks' : 'selected';
            }
            _notify();
          }),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      DashboardSelectorField<String>(
        initialValue: _filter,
        decoration: InputDecoration(labelText: tr(context, 'Отбор ресурсов')),
        items: [
          DropdownMenuItem(
            value: 'projects',
            child: Text(tr(context, 'По проектам')),
          ),
          DropdownMenuItem(
            value: 'labels',
            child: Text(tr(context, 'По меткам')),
          ),
          DropdownMenuItem(
            value: 'epics',
            child: Text(tr(context, 'По эпикам')),
          ),
        ],
        onChanged: (value) => setState(() {
          _filter = value ?? _filter;
          _notify();
        }),
      ),
      const SizedBox(height: 16),
      DashboardSelectorField<String>(
        key: ValueKey('resource-mode-${widget.projectId}:$_mode'),
        initialValue: _mode,
        decoration: InputDecoration(labelText: tr(context, 'Показатели')),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(tr(context, 'Все ресурсы')),
          ),
          DropdownMenuItem(
            value: 'selected',
            child: Text(tr(context, 'Выбранные ресурсы')),
          ),
          DropdownMenuItem(
            value: 'tasks',
            child: Text(tr(context, 'Прогресс задач')),
          ),
        ],
        onChanged: (value) => setState(() {
          _mode = value ?? _mode;
          _notify();
        }),
      ),
      if (_filter != 'projects' || _mode == 'selected')
        FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () {
                  widget.cubit.retryData(_key);
                  setState(_load);
                },
                child: Text(tr(context, 'Повторить загрузку фильтров')),
              );
            }
            if (!snapshot.hasData) {
              return const DashboardWidgetSkeleton(showHeading: false);
            }
            final labels = <String, String>{},
                epics = <String, String>{},
                names = <String, String>{};
            final selected = <String>{};
            if (_filter == 'projects' && widget.projectId != 'all') {
              selected.add(widget.projectId);
              for (final project in flattenDashboardProjects(widget.projects)) {
                if (project.id == widget.projectId) {
                  selected.addAll(
                    flattenDashboardProjects(project.children).map((e) => e.id),
                  );
                }
              }
            }
            for (final task in (snapshot.data as List).whereType<Map>()) {
              if (selected.isNotEmpty &&
                  !selected.contains(task['projectId'])) {
                continue;
              }
              for (final label
                  in (dashboardObject(task['detail'])['labels'] as List? ?? [])
                      .whereType<Map>()) {
                final text = label['text']?.toString() ?? '';
                if (text.isNotEmpty) {
                  labels[jsonEncode([
                        text.toLowerCase(),
                        label['color']?.toString() ?? '',
                      ])] =
                      text;
                }
              }
              for (final relation
                  in (task['epics'] as List? ?? []).whereType<Map>()) {
                final epic = dashboardObject(relation['epic'] ?? relation);
                final id = (relation['epicId'] ?? epic['id'])?.toString();
                if (id != null) epics[id] = epic['name']?.toString() ?? id;
              }
              final rows =
                  (task['resources'] as List? ?? []).whereType<Map>().toList()
                    ..sort(
                      (a, b) => ((a['order'] as num?) ?? 0).compareTo(
                        (b['order'] as num?) ?? 0,
                      ),
                    );
              for (var i = 0; i + 1 < rows.length; i += 2) {
                final plan = rows[i]['name']?.toString() ?? 'План',
                    fact = rows[i + 1]['name']?.toString() ?? 'Факт';
                names[jsonEncode([plan, fact])] = '$plan / $fact';
              }
            }
            return Column(
              children: [
                if (_filter == 'labels')
                  _choices(
                    labels,
                    _labels,
                    'Все метки',
                    'В выбранных проектах нет меток',
                  ),
                if (_filter == 'epics')
                  _choices(
                    epics,
                    _epics,
                    'Все эпики',
                    'В выбранных проектах нет эпиков',
                  ),
                if (_mode == 'selected')
                  _choices(
                    names,
                    _names,
                    'Все показатели',
                    'Нет пар план/факт',
                  ),
              ],
            );
          },
        ),
    ],
  );
}
