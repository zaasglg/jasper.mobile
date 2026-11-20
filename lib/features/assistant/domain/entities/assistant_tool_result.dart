import 'package:equatable/equatable.dart';
import 'assistant_draft.dart';

class AssistantToolResult extends Equatable {
  const AssistantToolResult({
    this.updated,
    this.action,
    this.results,
    this.draft,
    this.error,
    this.attachment,
    this.hasError = false,
  });
  final Map<String, dynamic>? updated;
  final Map<String, dynamic>? action;
  final List<dynamic>? results;
  final AssistantDraft? draft;
  final Object? error;
  final Map<String, dynamic>? attachment;
  final bool hasError;
  AssistantToolResult copyWith({
    Map<String, dynamic>? updated,
    Map<String, dynamic>? action,
    List<dynamic>? results,
    AssistantDraft? draft,
    Object? error,
    Map<String, dynamic>? attachment,
    bool? hasError,
  }) => AssistantToolResult(
    updated: updated ?? this.updated,
    action: action ?? this.action,
    results: results ?? this.results,
    draft: draft ?? this.draft,
    error: error ?? this.error,
    attachment: attachment ?? this.attachment,
    hasError: hasError ?? this.hasError,
  );
  @override
  List<Object?> get props => [
    updated,
    action,
    results,
    draft,
    error,
    attachment,
    hasError,
  ];
}
