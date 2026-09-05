import '../../data/models/task_detail_model.dart';
import '../../data/models/kanban_column_model.dart';

abstract interface class TaskDetailsRepository {
  Future<TaskDetailsPayload> getTask(String taskId);

  Future<List<TaskHistoryEntryModel>> getHistory(String taskId);

  Future<List<KanbanColumnModel>> getColumns(String projectId);

  Future<TaskDetailsPayload> updateProgress(String taskId, int progress);

  Future<TaskDetailsPayload> updateDetail(
    String taskId,
    TaskDetailModel detail,
  );

  Future<TaskDetailsPayload> updateEnd(String taskId, DateTime? end);
}

class TaskDetailsException implements Exception {
  const TaskDetailsException(this.message);

  final String message;

  @override
  String toString() => message;
}
