import 'package:equatable/equatable.dart';

/// A suggestion linked to an existing task; it never changes the source task.
class AiDayPlanEntry extends Equatable {
  const AiDayPlanEntry({
    required this.taskId,
    required this.projectId,
    required this.title,
    required this.reason,
    this.dueDate,
    this.durationMinutes = 30,
    this.startMinute,
    this.selected = true,
    this.saved = false,
  });

  factory AiDayPlanEntry.fromJson(Map<String, dynamic> json) {
    String requiredText(String key, int limit) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty || value.length > limit) {
        throw const FormatException('Некорректный план дня.');
      }
      return value.trim();
    }

    final duration = json['durationMinutes'];
    final minute = json['startMinute'];
    if (duration is! int ||
        duration < 15 ||
        duration > 180 ||
        (minute != null &&
            (minute is! int || minute < 0 || minute + duration > 1440))) {
      throw const FormatException('Некорректное время задачи.');
    }
    final due = json['dueDate'];
    if (due != null && (due is! String || DateTime.tryParse(due) == null)) {
      throw const FormatException('Некорректный срок задачи.');
    }
    return AiDayPlanEntry(
      taskId: requiredText('taskId', 128),
      projectId: requiredText('projectId', 128),
      title: requiredText('title', 500),
      reason: requiredText('reason', 500),
      dueDate: due == null ? null : DateTime.parse(due as String),
      durationMinutes: duration,
      startMinute: minute as int?,
      selected: json['selected'] != false,
      saved: json['saved'] == true,
    );
  }

  final String taskId, projectId, title, reason;
  final DateTime? dueDate;
  final int durationMinutes;
  final int? startMinute;
  final bool selected, saved;

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'projectId': projectId,
    'title': title,
    'reason': reason,
    'dueDate': dueDate?.toIso8601String(),
    'durationMinutes': durationMinutes,
    'startMinute': startMinute,
    'selected': selected,
    'saved': saved,
  };

  AiDayPlanEntry copyWith({
    int? durationMinutes,
    int? startMinute,
    bool clearTime = false,
    bool? selected,
    bool? saved,
  }) => AiDayPlanEntry(
    taskId: taskId,
    projectId: projectId,
    title: title,
    reason: reason,
    dueDate: dueDate,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    startMinute: clearTime ? null : startMinute ?? this.startMinute,
    selected: selected ?? this.selected,
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    taskId,
    projectId,
    title,
    reason,
    dueDate,
    durationMinutes,
    startMinute,
    selected,
    saved,
  ];
}
