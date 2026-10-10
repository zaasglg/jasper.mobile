import 'package:equatable/equatable.dart';

class AssistantMessageModel extends Equatable {
  const AssistantMessageModel({required this.role, required this.content});
  factory AssistantMessageModel.fromJson(Map<String, dynamic> json) =>
      AssistantMessageModel(
        role: json['role']?.toString() ?? 'assistant',
        content: json['content']?.toString() ?? '',
      );
  final String role, content;
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
  AssistantMessageModel copyWith({String? role, String? content}) =>
      AssistantMessageModel(
        role: role ?? this.role,
        content: content ?? this.content,
      );
  @override
  List<Object?> get props => [role, content];
}
