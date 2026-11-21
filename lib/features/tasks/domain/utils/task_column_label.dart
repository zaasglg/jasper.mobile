import '../entities/kanban_column_model.dart';

/// Status codes are project-local identifiers, never user-facing column names.
String taskColumnLabel(
  String status, {
  Iterable<KanbanColumnModel> columns = const [],
  String? name,
  String unavailable = 'Колонка недоступна',
}) {
  final code = status.trim().toUpperCase();
  final matches = columns.where(
    (c) => c.statusMap.trim().toUpperCase() == code && c.name.trim().isNotEmpty,
  );
  final column =
      matches.where((c) => !c.archived).firstOrNull ?? matches.firstOrNull;
  if (column != null) return column.name.trim();
  final explicit = name?.trim();
  if (explicit != null &&
      explicit.isNotEmpty &&
      explicit.toUpperCase() != code &&
      !RegExp(r'^COL\d+$', caseSensitive: false).hasMatch(explicit)) {
    return explicit;
  }
  return switch (code) {
    'BACKLOG' => 'Бэклог',
    'TODO' => 'К работе',
    'PROGRESS' || 'IN_PROGRESS' => 'В работе',
    'REVIEW' => 'На проверке',
    'DONE' => 'Готово',
    '' => 'Без колонки',
    _ => unavailable,
  };
}
