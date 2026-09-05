import '../../../projects/data/models/project_task_model.dart';

bool isTaskOverdue(ProjectTaskModel task, DateTime now) {
  final deadline = task.end;
  return deadline != null && !task.isDone && deadline.isBefore(now);
}

List<ProjectTaskModel> sortTasksByDeadline(
  Iterable<ProjectTaskModel> tasks, {
  required bool ascending,
  required DateTime now,
}) {
  final result = tasks.toList(growable: false);
  result.sort((left, right) {
    final categoryComparison = _deadlineCategory(
      left,
      now,
    ).compareTo(_deadlineCategory(right, now));
    if (categoryComparison != 0) return categoryComparison;

    final leftEnd = left.end;
    final rightEnd = right.end;
    if (leftEnd == null || rightEnd == null) {
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    }
    final comparison = leftEnd.compareTo(rightEnd);
    return ascending ? comparison : -comparison;
  });
  return result;
}

List<ProjectTaskModel> filterTasksByProjectIds(
  Iterable<ProjectTaskModel> tasks,
  Set<String> projectIds,
) {
  if (projectIds.isEmpty) return tasks.toList(growable: false);
  return tasks
      .where((task) => projectIds.contains(task.projectId))
      .toList(growable: false);
}

String formatRussianTaskDate(DateTime date) {
  const months = <String>[
    'янв.',
    'февр.',
    'мар.',
    'апр.',
    'мая',
    'июн.',
    'июл.',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ];
  final localDate = date.toLocal();
  return '${localDate.day} ${months[localDate.month - 1]} ${localDate.year}';
}

int _deadlineCategory(ProjectTaskModel task, DateTime now) {
  if (isTaskOverdue(task, now)) return 0;
  if (task.end != null) return 1;
  return 2;
}
