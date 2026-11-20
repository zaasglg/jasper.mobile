import 'package:equatable/equatable.dart';
import '../../domain/entities/inbox_task_detail.dart';
import 'inbox_task_label_dto.dart';

class InboxTaskDetailDto extends Equatable {
  const InboxTaskDetailDto(this.value);
  final Map<String, dynamic> value;
  factory InboxTaskDetailDto.fromJson(Map<String, dynamic> json) =>
      InboxTaskDetailDto(Map.of(json));
  Map<String, dynamic> toJson() => Map.of(value);
  factory InboxTaskDetailDto.fromEntity(InboxTaskDetail entity) =>
      InboxTaskDetailDto({
        ...entity.unknownDetailFields,
        if (entity.description != null) 'description': entity.description,
        if (entity.labels != null)
          'labels': entity.labels!
              .map((e) => InboxTaskLabelDto.fromEntity(e).toJson())
              .toList(),
        if (entity.completed != null) 'completed': entity.completed,
      });
  InboxTaskDetail toEntity() => InboxTaskDetail(
    description: value['description']?.toString(),
    labels: value['labels'] is List
        ? (value['labels'] as List)
              .whereType<Map>()
              .map(
                (e) => InboxTaskLabelDto.fromJson(
                  Map<String, dynamic>.from(e),
                ).toEntity(),
              )
              .toList()
        : null,
    completed: value['completed'] == null ? null : _bool(value['completed']),
    unknownDetailFields: {
      for (final entry in value.entries)
        if (!['description', 'labels', 'completed'].contains(entry.key))
          entry.key: entry.value,
    },
  );
  static bool _bool(Object? value) => value is bool
      ? value
      : value is num
      ? value != 0
      : ['true', '1', 'yes'].contains(value?.toString().toLowerCase());
  InboxTaskDetailDto copyWith({Map<String, dynamic>? value}) =>
      InboxTaskDetailDto(value ?? this.value);
  @override
  List<Object?> get props => [value];
}
