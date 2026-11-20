import 'package:equatable/equatable.dart';

class DashboardWidgetOptions extends Equatable {
  const DashboardWidgetOptions({
    this.mode,
    this.projectId,
    this.teamProjectId,
    this.resourceProjectId,
    this.resourceFilterType,
    this.projectIds,
    this.teamProjectIds,
    this.resourceLabelKeys,
    this.resourceEpicIds,
    this.resourceNames,
    this.resourceModeByProject,
    this.resourceNamesByProject,
    this.unknownOptions = const {},
  });
  final String? mode;
  final String? projectId;
  final String? teamProjectId;
  final String? resourceProjectId;
  final String? resourceFilterType;
  final List<String>? projectIds;
  final List<String>? teamProjectIds;
  final List<String>? resourceLabelKeys;
  final List<String>? resourceEpicIds;
  final List<String>? resourceNames;
  final Map<String, String>? resourceModeByProject;
  final Map<String, List<String>>? resourceNamesByProject;
  final Map<String, dynamic> unknownOptions;
  DashboardWidgetOptions copyWith({
    String? mode,
    String? projectId,
    String? teamProjectId,
    String? resourceProjectId,
    String? resourceFilterType,
    List<String>? projectIds,
    List<String>? teamProjectIds,
    List<String>? resourceLabelKeys,
    List<String>? resourceEpicIds,
    List<String>? resourceNames,
    Map<String, String>? resourceModeByProject,
    Map<String, List<String>>? resourceNamesByProject,
    Map<String, dynamic>? unknownOptions,
  }) => DashboardWidgetOptions(
    mode: mode ?? this.mode,
    projectId: projectId ?? this.projectId,
    teamProjectId: teamProjectId ?? this.teamProjectId,
    resourceProjectId: resourceProjectId ?? this.resourceProjectId,
    resourceFilterType: resourceFilterType ?? this.resourceFilterType,
    projectIds: projectIds ?? this.projectIds,
    teamProjectIds: teamProjectIds ?? this.teamProjectIds,
    resourceLabelKeys: resourceLabelKeys ?? this.resourceLabelKeys,
    resourceEpicIds: resourceEpicIds ?? this.resourceEpicIds,
    resourceNames: resourceNames ?? this.resourceNames,
    resourceModeByProject: resourceModeByProject ?? this.resourceModeByProject,
    resourceNamesByProject:
        resourceNamesByProject ?? this.resourceNamesByProject,
    unknownOptions: unknownOptions ?? this.unknownOptions,
  );
  @override
  List<Object?> get props => [
    mode,
    projectId,
    teamProjectId,
    resourceProjectId,
    resourceFilterType,
    projectIds,
    teamProjectIds,
    resourceLabelKeys,
    resourceEpicIds,
    resourceNames,
    resourceModeByProject,
    resourceNamesByProject,
    unknownOptions,
  ];
}
