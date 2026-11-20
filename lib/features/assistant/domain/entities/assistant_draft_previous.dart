import 'package:equatable/equatable.dart';

class AssistantDraftPrevious extends Equatable {
  const AssistantDraftPrevious({
    this.title,
    this.start,
    this.end,
    this.priority,
    this.hasValidValues = true,
  });
  final String? title;
  final String? start;
  final String? end;
  final String? priority;
  final bool hasValidValues;
  AssistantDraftPrevious copyWith({
    String? title,
    String? start,
    String? end,
    String? priority,
    bool? hasValidValues,
  }) => AssistantDraftPrevious(
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    priority: priority ?? this.priority,
    hasValidValues: hasValidValues ?? this.hasValidValues,
  );
  String? value(String key) => switch (key) {
    'title' => title,
    'start' => start,
    'end' => end,
    'priority' => priority,
    _ => null,
  };
  @override
  List<Object?> get props => [title, start, end, priority, hasValidValues];
}
