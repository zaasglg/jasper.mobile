import 'package:equatable/equatable.dart';

class TaskLabelModel extends Equatable {
  const TaskLabelModel({
    required this.id,
    required this.text,
    this.color = '#6366F1',
    this.isPersonal = false,
    this.raw = const <String, Object?>{},
  });

  factory TaskLabelModel.fromJson(Map<String, dynamic> json) {
    return TaskLabelModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#6366F1',
      isPersonal:
          json['isPersonal'] == true ||
          json['personal'] == true ||
          json['scope'] == 'personal',
      raw: Map<String, Object?>.from(json),
    );
  }

  final String id;
  final String text;
  final String color;
  final bool isPersonal;
  final Map<String, Object?> raw;

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...raw,
    'id': id,
    'text': text,
    'color': color,
    if (isPersonal) 'isPersonal': true,
  };

  TaskLabelModel copyWith({
    String? id,
    String? text,
    String? color,
    bool? isPersonal,
    Map<String, Object?>? raw,
  }) {
    return TaskLabelModel(
      id: id ?? this.id,
      text: text ?? this.text,
      color: color ?? this.color,
      isPersonal: isPersonal ?? this.isPersonal,
      raw: raw ?? this.raw,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, text, color, isPersonal, raw];
}
