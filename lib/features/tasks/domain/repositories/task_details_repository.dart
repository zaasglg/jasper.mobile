import '../../../projects/domain/entities/task_assignee_model.dart';
import '../../../projects/domain/entities/task_epic_model.dart';
import '../entities/task_label_model.dart';
import '../../data/models/task_detail_model.dart';
import '../entities/kanban_column_model.dart';

abstract interface class TaskLabelCatalogRepository {
  Future<({List<TaskLabelModel> shared, List<TaskLabelModel> personal})>
  getLabelCatalog(String taskId);
}

abstract interface class TaskExtrasRepository {
  Future<List<TaskEpicModel>> getEpics(String projectId);
  Future<TaskDetailsPayload> updateEpics(String taskId, List<String> ids);
  Future<void> saveResource(
    String taskId,
    TaskResourceModel resource, {
    required bool create,
  });
  Future<void> deleteResource(String resourceId);
}

abstract interface class ProjectEpicCreationRepository {
  Future<void> createEpic({
    required String projectId,
    required String name,
    required String color,
  });
}

abstract interface class TaskResourceOperationsRepository {
  Future<void> patchResource(String id, Map<String, Object?> changes);
  Future<Map<String, Object?>> resourceHistory(String id, {String? cursor});
}

abstract interface class TaskDatesRepository {
  Future<TaskDetailsPayload> updateDates(
    String taskId,
    DateTime? start,
    DateTime? end,
  );
}

abstract interface class TaskTitleRepository {
  Future<TaskDetailsPayload> updateTitle(String taskId, String title);
}

abstract interface class TaskAssigneesRepository {
  Future<List<TaskAssigneeModel>> getAssigneeCandidates(String projectId);
  Future<TaskDetailsPayload> updateAssignees(
    String taskId,
    List<String> userIds,
  );
}

abstract interface class TaskTimingRepository {
  Future<TaskDetailsPayload> updateEstimate(
    String taskId,
    int minutes, {
    TaskDetailModel? detail,
  });
}

abstract interface class TaskTimerRepository {
  Future<TaskDetailsPayload> timerAction(String taskId, String action);
}

abstract interface class TaskDetailsRepository {
  Future<TaskDetailsPayload> getTask(String taskId);

  Future<List<TaskHistoryEntryModel>> getHistory(String taskId);

  Future<List<KanbanColumnModel>> getColumns(String projectId);

  Future<TaskDetailsPayload> updateProgress(
    String taskId,
    int progress, {
    String? status,
  });

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

abstract interface class TaskAdvancedRepository {
  Future<TaskDetailsPayload> updateStart(String taskId, DateTime? start);
  Future<TaskDetailsPayload> updateDependencies(
    String taskId,
    List<String> displayIds,
  );
  Future<TaskCommentModel> postComment(
    String taskId,
    String text,
    List<TaskFileModel> files,
  );
}

abstract interface class TaskResourceCreationRepository {
  Future<TaskResourceModel> createResource(
    String taskId,
    TaskResourceModel resource,
  );
}
