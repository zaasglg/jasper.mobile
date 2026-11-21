import 'package:equatable/equatable.dart';
import '../../domain/entities/task_assignee_model.dart';

class TaskAssigneeDto extends Equatable {
  const TaskAssigneeDto({required this.userId, this.name = '', this.avatarUrl});

  factory TaskAssigneeDto.fromJson(Map<String, dynamic> json) {
    final nestedUser = json['user'];
    final nestedId = nestedUser is Map ? nestedUser['id'] : null;
    final user = nestedUser is Map
        ? Map<String, dynamic>.from(nestedUser)
        : const <String, dynamic>{};
    final firstName = user['firstName']?.toString().trim() ?? '';
    final lastName = user['lastName']?.toString().trim() ?? '';
    final fullName = '$firstName $lastName'.trim();
    return TaskAssigneeDto(
      userId:
          json['userId']?.toString() ??
          json['user_id']?.toString() ??
          nestedId?.toString() ??
          '',
      name:
          user['name']?.toString().trim() ??
          json['name']?.toString().trim() ??
          fullName,
      avatarUrl: _optionalString(
        user['avatarUrl'] ??
            user['avatar_url'] ??
            user['avatar'] ??
            json['avatarUrl'] ??
            json['avatar_url'] ??
            json['avatar'],
      ),
    );
  }

  final String userId;
  final String name;
  final String? avatarUrl;

  static String? _optionalString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'userId': userId,
    if (name.isNotEmpty) 'name': name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };

  TaskAssigneeDto copyWith({String? userId, String? name, String? avatarUrl}) {
    return TaskAssigneeDto(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => <Object?>[userId, name, avatarUrl];

  factory TaskAssigneeDto.fromEntity(TaskAssigneeModel entity) =>
      TaskAssigneeDto(
        userId: entity.userId,
        name: entity.name,
        avatarUrl: entity.avatarUrl,
      );
  TaskAssigneeModel toEntity() =>
      TaskAssigneeModel(userId: userId, name: name, avatarUrl: avatarUrl);
}
