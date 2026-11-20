import 'package:dio/dio.dart';
import '../../../projects/data/models/project_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import '../../../workspaces/domain/entities/workspace_model.dart';
import '../entities/task_move_target.dart';

abstract interface class TaskMoveRepository {
  Future<List<WorkspaceModel>> workspaces({CancelToken? cancelToken});
  Future<List<ProjectModel>> projects(
    String workspaceId, {
    CancelToken? cancelToken,
  });
  Future<List<KanbanColumnModel>> columns(
    String workspaceId,
    String projectId, {
    CancelToken? cancelToken,
  });
  Future<void> move(String taskId, TaskMoveTarget target);
}
