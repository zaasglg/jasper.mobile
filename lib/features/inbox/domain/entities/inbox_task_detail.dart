import 'package:equatable/equatable.dart';
import 'inbox_task_label.dart';

class InboxTaskDetail extends Equatable {
  const InboxTaskDetail({
    this.description,
    this.labels,
    this.completed,
    this.unknownDetailFields = const {},
  });
  final String? description;
  final List<InboxTaskLabel>? labels;
  final bool? completed;
  final Map<String, dynamic> unknownDetailFields;
  InboxTaskDetail copyWith({
    String? description,
    List<InboxTaskLabel>? labels,
    bool? completed,
    Map<String, dynamic>? unknownDetailFields,
  }) => InboxTaskDetail(
    description: description ?? this.description,
    labels: labels ?? this.labels,
    completed: completed ?? this.completed,
    unknownDetailFields: unknownDetailFields ?? this.unknownDetailFields,
  );
  @override
  List<Object?> get props => [
    description,
    labels,
    completed,
    unknownDetailFields,
  ];
}
