import 'package:equatable/equatable.dart';

enum CardField {
  completed('Завершенные задачи'),
  cover('Обложка'),
  id('ID задачи'),
  assignees('Участники'),
  dates('Сроки'),
  epics('Эпики'),
  labels('Метки'),
  personalLabels('Личные метки'),
  comments('Обсуждение'),
  timing('Тайминг'),
  checklists('Чек-листы'),
  resources('Ресурсы'),
  files('Количество файлов');

  const CardField(this.label);
  final String label;
}

class CardViewSettings extends Equatable {
  const CardViewSettings({this.hidden = const {}});
  final Set<CardField> hidden;
  bool shows(CardField field) => !hidden.contains(field);

  factory CardViewSettings.fromJson(Map<String, dynamic> json) {
    final values = json['hidden'];
    return CardViewSettings(
      hidden: Set.unmodifiable(
        CardField.values.where(
          (field) => values is List && values.contains(field.name),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'hidden': hidden.map((field) => field.name).toList(),
  };
  CardViewSettings copyWith({Set<CardField>? hidden}) =>
      CardViewSettings(hidden: Set.unmodifiable(hidden ?? this.hidden));
  CardViewSettings toggle(CardField field) {
    final updated = {...hidden};
    if (!updated.remove(field)) updated.add(field);
    return copyWith(hidden: updated);
  }

  @override
  List<Object?> get props => [hidden];
}
