import 'package:equatable/equatable.dart';

class TaskLabelModel extends Equatable {
  const TaskLabelModel({
    required this.id,
    required this.text,
    this.color = '#6366F1',
    this.isPersonal = false,
    this.unknownLabelFields = const <String, dynamic>{},
  });

  final String id;
  final String text;
  final String color;
  final bool isPersonal;
  final Map<String, dynamic> unknownLabelFields;

  TaskLabelModel copyWith({
    String? id,
    String? text,
    String? color,
    bool? isPersonal,
    Map<String, dynamic>? unknownLabelFields,
  }) {
    return TaskLabelModel(
      id: id ?? this.id,
      text: text ?? this.text,
      color: color ?? this.color,
      isPersonal: isPersonal ?? this.isPersonal,
      unknownLabelFields: unknownLabelFields ?? this.unknownLabelFields,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    text,
    color,
    isPersonal,
    unknownLabelFields,
  ];
}
