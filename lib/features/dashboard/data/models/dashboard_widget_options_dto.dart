import 'package:equatable/equatable.dart';
import '../../domain/entities/dashboard_widget_options.dart';

class DashboardWidgetOptionsDto extends Equatable {
  const DashboardWidgetOptionsDto(this.value);
  final Map<String, dynamic> value;
  factory DashboardWidgetOptionsDto.fromJson(Map<String, dynamic> json) =>
      DashboardWidgetOptionsDto(Map.of(json));
  Map<String, dynamic> toJson() => Map.of(value);
  factory DashboardWidgetOptionsDto.fromEntity(DashboardWidgetOptions entity) =>
      DashboardWidgetOptionsDto({
        ...entity.unknownOptions,
        if (entity.mode != null) 'mode': entity.mode,
        if (entity.projectId != null) 'projectId': entity.projectId,
        if (entity.teamProjectId != null) 'teamProjectId': entity.teamProjectId,
        if (entity.resourceProjectId != null)
          'resourceProjectId': entity.resourceProjectId,
        if (entity.resourceFilterType != null)
          'resourceFilterType': entity.resourceFilterType,
        if (entity.projectIds != null) 'projectIds': entity.projectIds,
        if (entity.teamProjectIds != null)
          'teamProjectIds': entity.teamProjectIds,
        if (entity.resourceLabelKeys != null)
          'resourceLabelKeys': entity.resourceLabelKeys,
        if (entity.resourceEpicIds != null)
          'resourceEpicIds': entity.resourceEpicIds,
        if (entity.resourceNames != null) 'resourceNames': entity.resourceNames,
        if (entity.resourceModeByProject != null)
          'resourceModeByProject': entity.resourceModeByProject,
        if (entity.resourceNamesByProject != null)
          'resourceNamesByProject': entity.resourceNamesByProject,
      });
  DashboardWidgetOptions toEntity() {
    List<String>? list(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : null;
    return DashboardWidgetOptions(
      mode: value['mode']?.toString(),
      projectId: value['projectId']?.toString(),
      teamProjectId: value['teamProjectId']?.toString(),
      resourceProjectId: value['resourceProjectId']?.toString(),
      resourceFilterType: value['resourceFilterType']?.toString(),
      projectIds: list(value['projectIds']),
      teamProjectIds: list(value['teamProjectIds']),
      resourceLabelKeys: list(value['resourceLabelKeys']),
      resourceEpicIds: list(value['resourceEpicIds']),
      resourceNames: list(value['resourceNames']),
      resourceModeByProject: value['resourceModeByProject'] is Map
          ? (value['resourceModeByProject'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : null,
      resourceNamesByProject: value['resourceNamesByProject'] is Map
          ? (value['resourceNamesByProject'] as Map).map(
              (k, v) => MapEntry(k.toString(), list(v) ?? <String>[]),
            )
          : null,
      unknownOptions: {
        for (final entry in value.entries)
          if (!knownKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  static const knownKeys = <String>{
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
  DashboardWidgetOptionsDto copyWith({Map<String, dynamic>? value}) =>
      DashboardWidgetOptionsDto(value ?? this.value);
  @override
  List<Object?> get props => [value];
}
