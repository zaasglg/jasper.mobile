import '../../data/models/planner_item_model.dart';

abstract interface class PlannerRepository {
  Future<List<PlannerItemModel>> load();
  Future<PlannerItemModel> create({
    required String title,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  });
  Future<void> update(
    PlannerItemModel item, {
    String? title,
    DateTime? scheduledAt,
    DateTime? plannedDate,
    int? durationMinutes,
    bool? completed,
  });
  Future<void> remove(String itemId);
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  });
}

class PlannerException implements Exception {
  const PlannerException(this.message);
  final String message;
  @override
  String toString() => message;
}
