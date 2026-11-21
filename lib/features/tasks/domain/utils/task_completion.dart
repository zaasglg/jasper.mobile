import '../../../projects/domain/entities/project_task_model.dart';
import '../entities/kanban_column_model.dart';

/// Reopening must clear DONE as well as progress, since either marks a task done.
String? reopenedTaskStatus(
  ProjectTaskModel task,
  Iterable<KanbanColumnModel> columns,
) {
  if (task.status.toUpperCase() != 'DONE') return null;
  final active =
      columns
          .where(
            (column) =>
                !column.archived &&
                column.statusMap.trim().isNotEmpty &&
                column.statusMap.toUpperCase() != 'DONE' &&
                (column.projectId.isEmpty ||
                    column.projectId == task.projectId),
          )
          .toList()
        ..sort((a, b) {
          final order = a.order.compareTo(b.order);
          return order != 0 ? order : a.name.compareTo(b.name);
        });
  return active.firstOrNull?.statusMap ?? 'TODO';
}
