import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../tasks/data/models/task_label_dto.dart';
import '../../../tasks/domain/entities/task_label_model.dart';
import '../../domain/entities/project_task_detail_snapshot.dart';
import 'project_task_cover_dto.dart';

class ProjectTaskDetailSnapshotDto extends Equatable {
  const ProjectTaskDetailSnapshotDto({this.fields = const {}, this.legacyText});

  factory ProjectTaskDetailSnapshotDto.fromJson(Map<String, dynamic> json) =>
      ProjectTaskDetailSnapshotDto(fields: Map.of(json));
  factory ProjectTaskDetailSnapshotDto.parse(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return ProjectTaskDetailSnapshotDto.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } on FormatException {
      // Legacy task descriptions are plain text rather than JSON objects.
    }
    return ProjectTaskDetailSnapshotDto(legacyText: value);
  }

  final Map<String, dynamic> fields;
  final String? legacyText;

  static List<TaskLabelModel> _labels(List values) => values
      .whereType<Map>()
      .map(
        (e) => TaskLabelDto.fromJson(Map<String, dynamic>.from(e)).toEntity(),
      )
      .toList(growable: false);

  ProjectTaskDetailSnapshot toEntity() {
    final unknown = Map<String, dynamic>.of(fields);
    final cover = fields['cover'];
    final labels = fields['labels'];
    final personal = fields['personalLabels'];
    if (cover is Map) unknown.remove('cover');
    if (labels is List) unknown.remove('labels');
    final byUser = <String, List<TaskLabelModel>>{};
    if (personal is Map) {
      final unparsed = Map<String, dynamic>.from(personal);
      for (final entry in personal.entries) {
        if (entry.value is List) {
          byUser[entry.key.toString()] = _labels(entry.value as List);
          unparsed.remove(entry.key);
        }
      }
      // Preserve empty maps and malformed per-user entries for round-trip.
      if (unparsed.isNotEmpty || personal.isEmpty) {
        unknown['personalLabels'] = unparsed;
      } else {
        unknown.remove('personalLabels');
      }
    } else if (personal is List) {
      unknown.remove('personalLabels');
    }
    return ProjectTaskDetailSnapshot(
      cover: cover is Map
          ? ProjectTaskCoverDto.fromJson(
              Map<String, dynamic>.from(cover),
              detail: fields,
            ).toEntity()
          : null,
      labels: labels is List ? _labels(labels) : null,
      personalLabelsByUser: byUser,
      legacyPersonalLabels: personal is List ? _labels(personal) : null,
      unknownDetailFields: unknown,
      legacyText: legacyText,
    );
  }

  factory ProjectTaskDetailSnapshotDto.fromEntity(
    ProjectTaskDetailSnapshot entity,
  ) {
    final json = Map<String, dynamic>.of(entity.unknownDetailFields);
    if (entity.cover != null) {
      json['cover'] = ProjectTaskCoverDto.fromEntity(entity.cover!).toJson();
    }
    if (entity.labels != null) {
      json['labels'] = entity.labels!
          .map((e) => TaskLabelDto.fromEntity(e).toJson())
          .toList();
    }
    if (entity.legacyPersonalLabels != null) {
      json['personalLabels'] = entity.legacyPersonalLabels!
          .map((e) => TaskLabelDto.fromEntity(e).toJson())
          .toList();
    }
    if (entity.personalLabelsByUser.isNotEmpty) {
      final existing = json['personalLabels'];
      json['personalLabels'] = <String, dynamic>{
        if (existing is Map) ...Map<String, dynamic>.from(existing),
        for (final entry in entity.personalLabelsByUser.entries)
          entry.key: entry.value
              .map((e) => TaskLabelDto.fromEntity(e).toJson())
              .toList(),
      };
    }
    return ProjectTaskDetailSnapshotDto(
      fields: json,
      legacyText: entity.legacyText,
    );
  }
  Map<String, dynamic> toJson() => Map.of(fields);
  String toApiValue() => legacyText ?? jsonEncode(toJson());
  ProjectTaskDetailSnapshotDto copyWith({
    Map<String, dynamic>? fields,
    String? legacyText,
  }) => ProjectTaskDetailSnapshotDto(
    fields: fields ?? this.fields,
    legacyText: legacyText ?? this.legacyText,
  );
  @override
  List<Object?> get props => [fields, legacyText];
}
