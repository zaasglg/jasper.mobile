import 'package:equatable/equatable.dart';

class TaskAssigneeModel extends Equatable {
  const TaskAssigneeModel({
    required this.userId,
    this.name = '',
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String? avatarUrl;

  TaskAssigneeModel copyWith({
    String? userId,
    String? name,
    String? avatarUrl,
  }) {
    return TaskAssigneeModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => <Object?>[userId, name, avatarUrl];
}
