import '../../domain/entities/task_label_model.dart';
import 'package:equatable/equatable.dart';

class TaskLabelDto extends Equatable {
  const TaskLabelDto({
    required this.id,
    required this.text,
    this.color = '#6366F1',
    this.isPersonal = false,
    this.unknownLabelFields = const <String, dynamic>{},
  });

  factory TaskLabelDto.fromJson(Map<String, dynamic> json) {
    return TaskLabelDto(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#6366F1',
      isPersonal:
          json['isPersonal'] == true ||
          json['personal'] == true ||
          json['scope'] == 'personal',
      unknownLabelFields: {
        for (final entry in json.entries)
          if (!['id', 'text', 'color', 'isPersonal'].contains(entry.key))
            entry.key: entry.value,
      },
    );
  }

  final String id;
  final String text;
  final String color;
  final bool isPersonal;
  final Map<String, dynamic> unknownLabelFields;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...unknownLabelFields,
    'id': id,
    'text': text,
    'color': color,
    if (isPersonal) 'isPersonal': true,
  };

  TaskLabelDto copyWith({
    String? id,
    String? text,
    String? color,
    bool? isPersonal,
    Map<String, dynamic>? unknownLabelFields,
  }) {
    return TaskLabelDto(
      id: id ?? this.id,
      text: text ?? this.text,
      color: color ?? this.color,
      isPersonal: isPersonal ?? this.isPersonal,
      unknownLabelFields: unknownLabelFields ?? this.unknownLabelFields,
    );
  }

  factory TaskLabelDto.fromEntity(TaskLabelModel entity) => TaskLabelDto(
    id: entity.id,
    text: entity.text,
    color: entity.color,
    isPersonal: entity.isPersonal,
    unknownLabelFields: entity.unknownLabelFields,
  );
  TaskLabelModel toEntity() => TaskLabelModel(
    id: id,
    text: text,
    color: color,
    isPersonal: isPersonal,
    unknownLabelFields: unknownLabelFields,
  );
  @override
  List<Object?> get props => <Object?>[
    id,
    text,
    color,
    isPersonal,
    unknownLabelFields,
  ];
}
