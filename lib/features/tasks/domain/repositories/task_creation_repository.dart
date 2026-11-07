import '../../../projects/data/models/project_model.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../data/models/task_creation_models.dart';

abstract interface class TaskCreationRepository {
  Future<TaskCreationCatalog> catalog();
  Future<List<ProjectModel>> projects(String workspaceId);
  Future<TaskCreationOptions> options(String workspaceId, String projectId);
  Future<TaskCreationResult> create(
    TaskCreationRequest request,
    List<ProjectTaskModel> siblings,
  );
}

class TaskCreationException implements Exception {
  const TaskCreationException(this.message);
  final String message;
  @override
  String toString() => message;
}
