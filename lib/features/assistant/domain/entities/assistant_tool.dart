import 'package:equatable/equatable.dart';
import 'assistant_tool_result.dart';

class AssistantTool extends Equatable {
  const AssistantTool({required this.name, this.result});
  final String name;
  final AssistantToolResult? result;
  AssistantTool copyWith({String? name, AssistantToolResult? result}) =>
      AssistantTool(name: name ?? this.name, result: result ?? this.result);
  @override
  List<Object?> get props => [name, result];
}
