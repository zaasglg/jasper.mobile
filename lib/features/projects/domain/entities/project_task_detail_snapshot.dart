import 'package:equatable/equatable.dart';
import '../../../tasks/domain/entities/task_label_model.dart';
import 'project_task_cover.dart';

class ProjectTaskDetailSnapshot extends Equatable {
  const ProjectTaskDetailSnapshot({
    this.cover,
    this.labels,
    this.personalLabelsByUser = const {},
    this.legacyPersonalLabels,
    this.unknownDetailFields = const {},
    this.legacyText,
  });

  final ProjectTaskCover? cover;
  final List<TaskLabelModel>? labels;
  final Map<String, List<TaskLabelModel>> personalLabelsByUser;
  final List<TaskLabelModel>? legacyPersonalLabels;
  final Map<String, dynamic> unknownDetailFields;
  final String? legacyText;

  ProjectTaskDetailSnapshot copyWith({
    ProjectTaskCover? cover,
    List<TaskLabelModel>? labels,
    Map<String, List<TaskLabelModel>>? personalLabelsByUser,
    List<TaskLabelModel>? legacyPersonalLabels,
    Map<String, dynamic>? unknownDetailFields,
    String? legacyText,
  }) => ProjectTaskDetailSnapshot(
    cover: cover ?? this.cover,
    labels: labels ?? this.labels,
    personalLabelsByUser: personalLabelsByUser ?? this.personalLabelsByUser,
    legacyPersonalLabels: legacyPersonalLabels ?? this.legacyPersonalLabels,
    unknownDetailFields: unknownDetailFields ?? this.unknownDetailFields,
    legacyText: legacyText ?? this.legacyText,
  );

  @override
  List<Object?> get props => [
    cover,
    labels,
    personalLabelsByUser,
    legacyPersonalLabels,
    unknownDetailFields,
    legacyText,
  ];
}
