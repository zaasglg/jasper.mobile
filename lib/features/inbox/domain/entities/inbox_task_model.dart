import 'inbox_task_detail.dart';
import 'package:equatable/equatable.dart';

class InboxTaskModel extends Equatable {
  const InboxTaskModel({
    required this.id,
    required this.title,
    this.displayId = '',
    this.description,
    this.completed = false,
    this.archived = false,
    this.order = 0,
    this.createdAt,
    this.isLocalOnly = false,
    this.detail = const InboxTaskDetail(),
    this.start,
    this.end,
    this.priority = 'MED',
  });

  final String id;
  final String displayId;
  final String title;
  final String? description;
  final bool completed;
  final bool archived;
  final int order;
  final DateTime? createdAt;
  final bool isLocalOnly;
  final InboxTaskDetail detail;
  final String? start, end;
  final String priority;

  InboxTaskModel copyWith({
    String? id,
    String? displayId,
    String? title,
    String? description,
    bool? completed,
    bool? archived,
    int? order,
    DateTime? createdAt,
    bool? isLocalOnly,
    InboxTaskDetail? detail,
    String? start,
    String? end,
    String? priority,
  }) {
    return InboxTaskModel(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      archived: archived ?? this.archived,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      detail: detail ?? this.detail,
      start: start ?? this.start,
      end: end ?? this.end,
      priority: priority ?? this.priority,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    displayId,
    title,
    description,
    completed,
    archived,
    order,
    createdAt,
    isLocalOnly,
    detail,
    start,
    end,
    priority,
  ];
}
