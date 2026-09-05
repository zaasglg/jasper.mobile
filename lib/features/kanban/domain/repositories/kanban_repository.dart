import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';
import '../entities/kanban_board_data.dart';

abstract interface class KanbanRepository {
  Future<KanbanBoardData> loadBoard(
    String projectId, {
    String? search,
    int take = 100,
    int skip = 0,
  });

  void cancelPendingLoads();

  Future<ProjectTaskModel> createTask({
    required String projectId,
    required String title,
    required String status,
    required String priority,
  });

  Future<void> moveTask({
    required String taskId,
    required String projectId,
    required String status,
    required int position,
  });

  Future<KanbanColumnModel> createColumn({
    required String projectId,
    required String name,
    required int order,
    int? wip,
  });

  Future<KanbanColumnModel> updateColumn({
    required String columnId,
    required String name,
    int? wip,
  });

  Future<void> reorderColumns(String projectId, List<String> ids);
  Future<void> archiveColumn(String columnId);
  Future<void> deleteColumn(String columnId);
}

class KanbanException implements Exception {
  const KanbanException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
