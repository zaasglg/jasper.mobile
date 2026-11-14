import 'package:equatable/equatable.dart';
import 'task_label_model.dart';

String taskLabelKey(String text) => text.trim().toLowerCase();

List<TaskLabelModel> uniqueTaskLabels(Iterable<TaskLabelModel> labels) {
  final result = <String, TaskLabelModel>{};
  for (final label in labels) {
    final key = taskLabelKey(label.text);
    if (key.isNotEmpty) result.putIfAbsent(key, () => label);
  }
  return result.values.toList();
}

class TaskLabelCatalog extends Equatable {
  const TaskLabelCatalog({this.shared = const [], this.personal = const []});
  final List<TaskLabelModel> shared, personal;

  factory TaskLabelCatalog.fromJson(Map<String, dynamic> json) {
    List<TaskLabelModel> parse(Object? value) => value is List
        ? uniqueTaskLabels(
            value.whereType<Map>().map(
              (item) =>
                  TaskLabelModel.fromJson(Map<String, dynamic>.from(item)),
            ),
          )
        : [];
    return TaskLabelCatalog(
      shared: parse(json['shared']),
      personal: parse(json['personal']),
    );
  }
  Map<String, dynamic> toJson() => {
    'shared': shared.map((e) => e.toJson()).toList(),
    'personal': personal.map((e) => e.toJson()).toList(),
  };
  TaskLabelCatalog copyWith({
    List<TaskLabelModel>? shared,
    List<TaskLabelModel>? personal,
  }) => TaskLabelCatalog(
    shared: shared ?? this.shared,
    personal: personal ?? this.personal,
  );
  @override
  List<Object?> get props => [shared, personal];
}
