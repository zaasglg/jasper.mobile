import '../../data/models/project_task_model.dart';

abstract interface class ProjectTaskRepository {
  Future<List<ProjectTaskModel>> getTasksForProjectIds(List<String> projectIds);
}
