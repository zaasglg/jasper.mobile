import 'package:equatable/equatable.dart';

import '../../data/models/inbox_task_model.dart';

enum InboxStatus { initial, loading, success, failure }

class InboxState extends Equatable {
  const InboxState({
    this.status = InboxStatus.initial,
    this.tasks = const <InboxTaskModel>[],
    this.errorMessage,
  });

  final InboxStatus status;
  final List<InboxTaskModel> tasks;
  final String? errorMessage;

  InboxState copyWith({
    InboxStatus? status,
    List<InboxTaskModel>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InboxState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, tasks, errorMessage];
}
