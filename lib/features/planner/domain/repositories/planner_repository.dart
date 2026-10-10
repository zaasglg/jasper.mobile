import '../../data/models/planner_item_model.dart';

abstract interface class PlannerRepository {
  Future<List<PlannerItemModel>> load(String workspaceId);
  Future<PlannerItemModel> create(
    String workspaceId, {
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  });
  Future<void> update(
    PlannerItemModel item, {
    String? title,
    DateTime? scheduledAt,
    int? durationMinutes,
    bool? completed,
  });
  Future<void> remove(String itemId);
  Future<void> addTask(
    String workspaceId, {
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  });
}

class PlannerException implements Exception {
  const PlannerException(this.message);
  final String message;
  @override
  String toString() => message;
}
