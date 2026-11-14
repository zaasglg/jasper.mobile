import 'dashboard_resource_options.dart';
import 'dashboard_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../projects/data/models/project_model.dart';
import '../../data/dashboard_layout.dart';
import '../cubit/dashboard_layout_cubit.dart';
import 'dashboard_widget_panel.dart';

Future<void> showDashboardWidgetPicker(
  BuildContext context,
  DashboardLayoutCubit cubit,
) async {
  final current = cubit.state;
  if (!current.editing || current.saving) return;
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      minChildSize: .35,
      maxChildSize: .9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text(
            'Добавить виджет',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final definition in DashboardWidgetDefinition.all.where(
            (definition) => definition.available,
          ))
            Builder(
              builder: (context) {
                final existing = current.current!.widgets.any(
                  (e) => e.id == definition.id && e.visible,
                );
                final enabled = definition.duplicable || !existing;
                return ListTile(
                  enabled: enabled,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    dashboardWidgetIcon(definition.id),
                    size: 16,
                    color: enabled ? AppColors.accent : AppColors.muted,
                  ),
                  title: Text(
                    definition.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    existing && !enabled
                        ? 'Уже на дашборде'
                        : definition.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  trailing: Icon(
                    enabled ? LucideIcons.plus : LucideIcons.check,
                    size: 16,
                  ),
                  onTap: () => Navigator.pop(context, definition.id),
                );
              },
            ),
        ],
      ),
    ),
  );
  if (id != null &&
      !cubit.isClosed &&
      cubit.state.workspaceId == current.workspaceId) {
    cubit.add(id);
  }
}

Future<void> showDashboardWidgetSettings(
  BuildContext context,
  DashboardLayoutCubit cubit,
  DashboardWidgetSlot slot,
  List<ProjectModel> projects,
) async {
  final workspaceId = cubit.state.workspaceId;
  final minimumHeight = ((slot.definition?.rows ?? 14) * 24 - 16).toDouble();
  var height = (slot.height ?? minimumHeight)
      .clamp(minimumHeight, 900)
      .toDouble();
  var size = slot.id == 'kpi-group' && slot.size == 'third'
      ? 'half'
      : slot.size;
  Map<String, dynamic> resourceChanges = {};
  var mode = slot.options['mode'] == 'epic' ? 'epic' : 'column';
  final projectKey = slot.id == 'team' ? 'teamProjectIds' : 'projectIds';
  final original =
      slot.options[projectKey] ??
      (slot.id == 'resource'
          ? (slot.options['resourceProjectId'] == null ||
                    slot.options['resourceProjectId'] == 'all'
                ? []
                : [slot.options['resourceProjectId']])
          : slot.options['projectId'] != null
          ? [slot.options['projectId']]
          : slot.id == 'team' &&
                slot.options['teamProjectId'] != null &&
                slot.options['teamProjectId'] != 'all'
          ? [slot.options['teamProjectId']]
          : []);
  final selected = (original is List ? original : [])
      .map((e) => e.toString())
      .toSet();
  final canFilter = [
    'kpi-group',
    'tasks-summary',
    'team',
    'mentions',
    'resource',
    'task-map',
  ].contains(slot.id);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => FractionallySizedBox(
        heightFactor: .85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                slot.definition?.title ?? slot.id,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const Text(
                    'Высота',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  Slider(
                    value: height.clamp(minimumHeight, 900),
                    min: minimumHeight,
                    max: 900,
                    divisions: 30,
                    label: '${height.round()}',
                    onChanged: (value) => setState(() => height = value),
                  ),
                  const SizedBox(height: 8),
                  DashboardSelectorField<String>(
                    initialValue: size,
                    decoration: const InputDecoration(
                      labelText: 'Ширина на большом экране',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'full',
                        child: Text('На всю ширину'),
                      ),
                      const DropdownMenuItem(
                        value: 'half',
                        child: Text('Половина'),
                      ),
                      if (slot.id != 'kpi-group')
                        const DropdownMenuItem(
                          value: 'third',
                          child: Text('Треть'),
                        ),
                    ],
                    onChanged: (value) => setState(() => size = value ?? size),
                  ),
                  if (slot.id == 'tasks-summary') ...[
                    const SizedBox(height: 16),
                    DashboardSelectorField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(
                        labelText: 'Группировка',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'column',
                          child: Text('По колонкам'),
                        ),
                        DropdownMenuItem(
                          value: 'epic',
                          child: Text('По эпикам'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => mode = value ?? mode),
                    ),
                  ],
                  if (canFilter) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Проекты',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Все проекты',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: selected.isEmpty,
                      onChanged: (_) => setState(selected.clear),
                    ),
                    for (final project in flattenDashboardProjects(projects))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          project.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: selected.contains(project.id),
                        onChanged: (value) => setState(() {
                          if (slot.id == 'resource') selected.clear();
                          value == true
                              ? selected.add(project.id)
                              : selected.remove(project.id);
                        }),
                      ),
                  ],
                  if (slot.id == 'resource')
                    DashboardResourceOptions(
                      cubit: cubit,
                      projects: projects,
                      projectId: selected.firstOrNull ?? 'all',
                      options: slot.options,
                      onChanged: (changes) => resourceChanges = changes,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Применить'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (result != true ||
      cubit.isClosed ||
      workspaceId != cubit.state.workspaceId ||
      !cubit.state.editing) {
    return;
  }
  cubit.update(slot.instanceId, {
    'height': height,
    'size': size,
    if (slot.id == 'tasks-summary') 'mode': mode,
    if (canFilter && slot.id != 'resource') projectKey: selected.toList(),
    if (slot.id == 'resource') ...resourceChanges,
    if (slot.id == 'resource')
      'resourceProjectId': selected.firstOrNull ?? 'all',
  });
}

class DashboardEditActions extends StatelessWidget {
  const DashboardEditActions({
    required this.slot,
    required this.cubit,
    required this.projects,
    required this.index,
    required this.count,
    super.key,
  });
  final DashboardWidgetSlot slot;
  final DashboardLayoutCubit cubit;
  final List<ProjectModel> projects;
  final int index, count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ReorderableDragStartListener(
        index: index,
        enabled: !cubit.state.saving,
        key: ValueKey('dashboard_drag_${slot.instanceId}'),
        child: const ColoredBox(
          color: Colors.transparent,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: 'Перетащить виджет',
              child: Icon(
                LucideIcons.gripVertical,
                size: 16,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: ReorderableDelayedDragStartListener(
          index: index,
          enabled: !cubit.state.saving,
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minHeight: 48),
            child: Text(
              slot.definition?.title ?? slot.id,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      AppActionMenuButton<String>(
        title: slot.definition?.title ?? slot.id,
        enabled: !cubit.state.saving,
        groups: [
          [
            const AppMenuAction(
              value: 'settings',
              label: 'Настройки',
              icon: LucideIcons.slidersHorizontal,
            ),
            if (slot.definition?.duplicable ?? false)
              const AppMenuAction(
                value: 'duplicate',
                label: 'Добавить ещё такой',
                icon: LucideIcons.copy,
              ),
            AppMenuAction(
              value: 'up',
              label: 'Выше',
              icon: LucideIcons.arrowUp,
              enabled: index > 0,
            ),
            AppMenuAction(
              value: 'down',
              label: 'Ниже',
              icon: LucideIcons.arrowDown,
              enabled: index + 1 < count,
            ),
          ],
          [
            const AppMenuAction(
              value: 'hide',
              label: 'Скрыть виджет',
              icon: LucideIcons.eyeOff,
            ),
          ],
        ],
        onSelected: (value) async {
          switch (value) {
            case 'duplicate':
              cubit.add(slot.id);
            case 'settings':
              await showDashboardWidgetSettings(context, cubit, slot, projects);
            case 'hide':
              cubit.update(slot.instanceId, {'visible': false});
            case 'up':
              cubit.reorder(index, index - 1);
            case 'down':
              cubit.reorder(index, index + 1);
          }
        },
      ),
    ],
  );
}

Future<void> confirmDashboardReset(
  BuildContext context,
  DashboardLayoutCubit cubit,
) async {
  if (await showAppConfirmation(
        context,
        'Сбросить виджеты?',
        'Будет восстановлен стандартный набор. Изменения применятся после сохранения.',
        confirmLabel: 'Сбросить',
      ) &&
      !cubit.isClosed) {
    cubit.reset();
  }
}
