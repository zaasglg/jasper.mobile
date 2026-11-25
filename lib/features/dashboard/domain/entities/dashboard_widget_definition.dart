import 'package:equatable/equatable.dart';

class DashboardWidgetDefinition extends Equatable {
  const DashboardWidgetDefinition(
    this.id,
    this.title,
    this.description, {
    this.duplicable = false,
    this.rows = 14,
  });
  final String id, title, description;
  final bool duplicable;
  final int rows;
  DashboardWidgetDefinition copyWith({
    String? id,
    String? title,
    String? description,
    bool? duplicable,
    int? rows,
  }) => DashboardWidgetDefinition(
    id ?? this.id,
    title ?? this.title,
    description ?? this.description,
    duplicable: duplicable ?? this.duplicable,
    rows: rows ?? this.rows,
  );
  @override
  List<Object?> get props => [id, title, description, duplicable, rows];
  bool get available => id != 'calendar';
  static const all = [
    DashboardWidgetDefinition(
      'daily-motivation',
      'AI',
      'Фокус дня и рекомендации',
      rows: 11,
    ),
    DashboardWidgetDefinition(
      'kpi-group',
      'KPI-показатели',
      'Обзор проектов и задач',
    ),
    DashboardWidgetDefinition(
      'tasks-summary',
      'Скрам',
      'Прогресс по колонкам и эпикам',
      duplicable: true,
    ),
    DashboardWidgetDefinition(
      'activity',
      'Активность',
      'Последние события workspace',
    ),
    DashboardWidgetDefinition(
      'my-tasks',
      'Мои задачи',
      'Назначенные мне задачи',
      rows: 15,
    ),
    DashboardWidgetDefinition(
      'team',
      'Команда',
      'Участники и нагрузка',
      duplicable: true,
      rows: 15,
    ),
    DashboardWidgetDefinition('mentions', 'Упоминания', 'Упоминания и реакции'),
    DashboardWidgetDefinition(
      'calendar',
      'Ежедневник',
      'Запланированные дела',
      rows: 16,
    ),
    DashboardWidgetDefinition(
      'resource',
      'Ресурс',
      'План и факт по ресурсам',
      duplicable: true,
      rows: 20,
    ),
  ];
  static DashboardWidgetDefinition? find(String id) {
    for (final value in all) {
      if (value.id == id) return value;
    }
    return null;
  }
}
