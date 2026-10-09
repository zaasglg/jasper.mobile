import 'package:equatable/equatable.dart';

import '../../data/models/inbox_task_model.dart';

enum InboxStatus { initial, loading, success, failure }

class InboxState extends Equatable {
  const InboxState({
    this.status = InboxStatus.initial,
    this.tasks = const <InboxTaskModel>[],
    this.errorMessage,
    this.isCreating = false,
    this.creationErrorMessage,
    this.completingTaskIds = const <String>{},
    this.completionErrorMessage,
  });

  final InboxStatus status;
  final List<InboxTaskModel> tasks;
  final String? errorMessage;
  final bool isCreating;
  final String? creationErrorMessage;
  final Set<String> completingTaskIds;
  final String? completionErrorMessage;

  InboxState copyWith({
    InboxStatus? status,
    List<InboxTaskModel>? tasks,
    String? errorMessage,
    bool clearError = false,
    bool? isCreating,
    String? creationErrorMessage,
    bool clearCreationError = false,
    Set<String>? completingTaskIds,
    String? completionErrorMessage,
    bool clearCompletionError = false,
  }) {
    return InboxState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isCreating: isCreating ?? this.isCreating,
      creationErrorMessage: clearCreationError
          ? null
          : creationErrorMessage ?? this.creationErrorMessage,
      completingTaskIds: completingTaskIds ?? this.completingTaskIds,
      completionErrorMessage: clearCompletionError
          ? null
          : completionErrorMessage ?? this.completionErrorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    tasks,
    errorMessage,
    isCreating,
    creationErrorMessage,
    completingTaskIds,
    completionErrorMessage,
  ];
}
