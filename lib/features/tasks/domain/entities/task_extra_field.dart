enum TaskExtraField { id, column, epics }

extension TaskExtraFieldLabel on TaskExtraField {
  String get label => switch (this) {
    TaskExtraField.id => 'ID',
    TaskExtraField.column => 'Колонка',
    TaskExtraField.epics => 'Эпики',
  };
}
