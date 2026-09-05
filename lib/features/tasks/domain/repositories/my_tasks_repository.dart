import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/kanban_column_model.dart';

abstract interface class MyTasksRepository {
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const <String>[],
  });

  Future<List<KanbanColumnModel>> getKanbanColumns(String projectId);

  Future<void> updateProgress(String taskId, int progress);
}
