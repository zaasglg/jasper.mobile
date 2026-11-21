import '../entities/task_label_model.dart';

String taskLabelKey(String text) => text.trim().toLowerCase();

List<TaskLabelModel> uniqueTaskLabels(Iterable<TaskLabelModel> labels) {
  final result = <String, TaskLabelModel>{};
  for (final label in labels) {
    final key = taskLabelKey(label.text);
    if (key.isNotEmpty) result.putIfAbsent(key, () => label);
  }
  return result.values.toList();
}
