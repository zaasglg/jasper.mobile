import 'package:equatable/equatable.dart';
import '../../domain/entities/task_label_model.dart';
import '../../domain/utils/task_label_utils.dart';
import 'task_label_dto.dart';

class TaskLabelCatalogDto extends Equatable {
  const TaskLabelCatalogDto({this.shared = const [], this.personal = const []});
  final List<TaskLabelDto> shared, personal;
  factory TaskLabelCatalogDto.fromJson(Map<String, dynamic> json) {
    List<TaskLabelDto> parse(Object? value) {
      if (value is! List) return [];
      final seen = <String>{};
      return value
          .whereType<Map>()
          .map((item) => TaskLabelDto.fromJson(Map<String, dynamic>.from(item)))
          .where((label) {
            final key = taskLabelKey(label.text);
            return key.isNotEmpty && seen.add(key);
          })
          .toList();
    }

    return TaskLabelCatalogDto(
      shared: parse(json['shared']),
      personal: parse(json['personal']),
    );
  }
  Map<String, dynamic> toJson() => {
    'shared': shared.map((e) => e.toJson()).toList(),
    'personal': personal.map((e) => e.toJson()).toList(),
  };
  factory TaskLabelCatalogDto.fromEntity(
    ({List<TaskLabelModel> shared, List<TaskLabelModel> personal}) entity,
  ) => TaskLabelCatalogDto(
    shared: entity.shared.map(TaskLabelDto.fromEntity).toList(),
    personal: entity.personal.map(TaskLabelDto.fromEntity).toList(),
  );
  ({List<TaskLabelModel> shared, List<TaskLabelModel> personal}) toEntity() => (
    shared: shared.map((e) => e.toEntity()).toList(),
    personal: personal.map((e) => e.toEntity()).toList(),
  );
  TaskLabelCatalogDto copyWith({
    List<TaskLabelDto>? shared,
    List<TaskLabelDto>? personal,
  }) => TaskLabelCatalogDto(
    shared: shared ?? this.shared,
    personal: personal ?? this.personal,
  );
  @override
  List<Object?> get props => [shared, personal];
}
