import 'package:equatable/equatable.dart';
import '../../domain/entities/task_epic_model.dart';

class TaskEpicDto extends Equatable {
  const TaskEpicDto({
    required this.id,
    required this.name,
    this.color = '#6d5fe0',
  });

  factory TaskEpicDto.fromJson(Map<String, dynamic> json) {
    final nestedEpic = json['epic'];
    final epic = nestedEpic is Map
        ? Map<String, dynamic>.from(nestedEpic)
        : const <String, dynamic>{};
    return TaskEpicDto(
      id:
          json['epicId']?.toString() ??
          json['epic_id']?.toString() ??
          epic['id']?.toString() ??
          json['id']?.toString() ??
          '',
      name: epic['name']?.toString() ?? json['name']?.toString() ?? '',
      color:
          epic['color']?.toString() ?? json['color']?.toString() ?? '#6d5fe0',
    );
  }

  final String id;
  final String name;
  final String color;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'epicId': id,
    'epic': <String, dynamic>{'id': id, 'name': name, 'color': color},
  };

  TaskEpicDto copyWith({String? id, String? name, String? color}) {
    return TaskEpicDto(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, color];

  factory TaskEpicDto.fromEntity(TaskEpicModel entity) =>
      TaskEpicDto(id: entity.id, name: entity.name, color: entity.color);
  TaskEpicModel toEntity() => TaskEpicModel(id: id, name: name, color: color);
}
