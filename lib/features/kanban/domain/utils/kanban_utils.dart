import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/data/models/kanban_column_model.dart';

List<KanbanColumnModel> sortKanbanColumns(Iterable<KanbanColumnModel> columns) {
  return columns.toList(growable: false)..sort((left, right) {
    final order = left.order.compareTo(right.order);
    return order != 0 ? order : left.name.compareTo(right.name);
  });
}

Map<String, List<ProjectTaskModel>> groupKanbanTasks(
  Iterable<KanbanColumnModel> columns,
  Iterable<ProjectTaskModel> tasks,
) {
  final result = <String, List<ProjectTaskModel>>{
    for (final column in columns)
      column.statusMap.toUpperCase(): <ProjectTaskModel>[],
  };
  for (final task in tasks) {
    result
        .putIfAbsent(task.status.toUpperCase(), () => <ProjectTaskModel>[])
        .add(task);
  }
  for (final values in result.values) {
    values.sort((left, right) {
      final order = left.order.compareTo(right.order);
      return order != 0 ? order : left.title.compareTo(right.title);
    });
  }
  return result;
}

List<ProjectTaskModel> moveKanbanTask({
  required List<ProjectTaskModel> tasks,
  required String taskId,
  required String projectId,
  required String targetStatus,
  required int targetPosition,
}) {
  final moving = tasks.where((task) => task.id == taskId).firstOrNull;
  if (moving == null) return tasks;

  final without = tasks
      .where((task) => task.id != taskId)
      .toList(growable: true);
  final target =
      without
          .where(
            (task) => task.status.toUpperCase() == targetStatus.toUpperCase(),
          )
          .toList(growable: true)
        ..sort((left, right) => left.order.compareTo(right.order));
  final position = targetPosition.clamp(0, target.length);
  target.insert(
    position,
    moving.copyWith(projectId: projectId, status: targetStatus),
  );
  final targetIds = target.map((task) => task.id).toSet();
  final result = without
      .where((task) => !targetIds.contains(task.id))
      .toList(growable: true);
  result.addAll(<ProjectTaskModel>[
    for (var index = 0; index < target.length; index++)
      target[index].copyWith(order: index),
  ]);
  return result;
}
