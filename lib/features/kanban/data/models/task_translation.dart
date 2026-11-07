import 'dart:convert';
import 'package:equatable/equatable.dart';

class TaskTranslation extends Equatable {
  const TaskTranslation({required this.title, required this.description});
  final String title;
  final String description;

  factory TaskTranslation.fromJson(Map<String, dynamic> json) {
    if (json['title'] is! String ||
        (json['title'] as String).trim().isEmpty ||
        json['description'] is! String) {
      throw const FormatException('Некорректный перевод задачи.');
    }
    return TaskTranslation(
      title: (json['title'] as String).trim(),
      description: json['description'] as String,
    );
  }
  factory TaskTranslation.fromContent(String content) {
    final text = content
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Некорректный перевод.');
    }
    return TaskTranslation.fromJson(value);
  }
  Map<String, dynamic> toJson() => {'title': title, 'description': description};
  TaskTranslation copyWith({String? title, String? description}) =>
      TaskTranslation(
        title: title ?? this.title,
        description: description ?? this.description,
      );
  @override
  List<Object?> get props => [title, description];
}
