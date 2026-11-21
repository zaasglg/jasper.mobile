import 'package:equatable/equatable.dart';

class TaskEpicModel extends Equatable {
  const TaskEpicModel({
    required this.id,
    required this.name,
    this.color = '#6d5fe0',
  });

  final String id;
  final String name;
  final String color;

  TaskEpicModel copyWith({String? id, String? name, String? color}) {
    return TaskEpicModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, color];
}
