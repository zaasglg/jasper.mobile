import '../../domain/entities/dashboard_widget_options.dart';
import '../../domain/entities/dashboard_widget_slot.dart';

DashboardWidgetOptions patchDashboardOptions(
  DashboardWidgetOptions current,
  Map<String, dynamic> changes,
) {
  List<String>? list(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList() : null;
  return DashboardWidgetOptions(
    mode: changes.containsKey('mode')
        ? changes['mode']?.toString()
        : current.mode,
    projectId: changes.containsKey('projectId')
        ? changes['projectId']?.toString()
        : current.projectId,
    teamProjectId: changes.containsKey('teamProjectId')
        ? changes['teamProjectId']?.toString()
        : current.teamProjectId,
    resourceProjectId: changes.containsKey('resourceProjectId')
        ? changes['resourceProjectId']?.toString()
        : current.resourceProjectId,
    resourceFilterType: changes.containsKey('resourceFilterType')
        ? changes['resourceFilterType']?.toString()
        : current.resourceFilterType,
    projectIds: changes.containsKey('projectIds')
        ? list(changes['projectIds'])
        : current.projectIds,
    teamProjectIds: changes.containsKey('teamProjectIds')
        ? list(changes['teamProjectIds'])
        : current.teamProjectIds,
    resourceLabelKeys: changes.containsKey('resourceLabelKeys')
        ? list(changes['resourceLabelKeys'])
        : current.resourceLabelKeys,
    resourceEpicIds: changes.containsKey('resourceEpicIds')
        ? list(changes['resourceEpicIds'])
        : current.resourceEpicIds,
    resourceNames: changes.containsKey('resourceNames')
        ? list(changes['resourceNames'])
        : current.resourceNames,
    resourceModeByProject: changes.containsKey('resourceModeByProject')
        ? (changes['resourceModeByProject'] is Map
              ? (changes['resourceModeByProject'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                )
              : null)
        : current.resourceModeByProject,
    resourceNamesByProject: changes.containsKey('resourceNamesByProject')
        ? (changes['resourceNamesByProject'] is Map
              ? (changes['resourceNamesByProject'] as Map).map(
                  (k, v) => MapEntry(k.toString(), list(v) ?? <String>[]),
                )
              : null)
        : current.resourceNamesByProject,
    unknownOptions: {
      ...current.unknownOptions,
      for (final entry in changes.entries)
        if (!knownDashboardOptionKeys.contains(entry.key) &&
            ![
              'id',
              'instanceId',
              'size',
              'visible',
              'height',
            ].contains(entry.key))
          entry.key: entry.value,
    },
  );
}

const knownDashboardOptionKeys = <String>{
  'mode',
  'projectId',
  'teamProjectId',
  'resourceProjectId',
  'resourceFilterType',
  'projectIds',
  'teamProjectIds',
  'resourceLabelKeys',
  'resourceEpicIds',
  'resourceNames',
  'resourceModeByProject',
  'resourceNamesByProject',
};
DashboardWidgetSlot patchDashboardSlot(
  DashboardWidgetSlot slot,
  Map<String, dynamic> changes,
) => DashboardWidgetSlot(
  id: changes.containsKey('id') ? changes['id']?.toString() ?? '' : slot.id,
  instanceId: changes.containsKey('instanceId')
      ? changes['instanceId']?.toString() ?? ''
      : slot.instanceId,
  visible: changes.containsKey('visible')
      ? changes['visible'] != false
      : slot.visible,
  size: changes.containsKey('size')
      ? (['full', 'half', 'third'].contains(changes['size'])
            ? changes['size'] as String
            : 'half')
      : slot.size,
  height: changes.containsKey('height')
      ? (changes['height'] as num?)?.toDouble().clamp(180, 900)
      : slot.height,
  options: patchDashboardOptions(slot.options, changes),
);
