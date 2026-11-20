import 'package:equatable/equatable.dart';
import '../../domain/entities/inbox_task_label.dart';

class InboxTaskLabelDto extends Equatable {
  const InboxTaskLabelDto(this.value);
  final Map<String, dynamic> value;
  factory InboxTaskLabelDto.fromJson(Map<String, dynamic> json) =>
      InboxTaskLabelDto(Map.of(json));
  Map<String, dynamic> toJson() => Map.of(value);
  factory InboxTaskLabelDto.fromEntity(InboxTaskLabel entity) =>
      InboxTaskLabelDto({
        if (entity.id != null) 'id': entity.id,
        if (entity.text != null) 'text': entity.text,
        if (entity.color != null) 'color': entity.color,
      });
  InboxTaskLabel toEntity() => InboxTaskLabel(
    id: value['id']?.toString(),
    text: value['text']?.toString(),
    color: value['color']?.toString(),
  );
  InboxTaskLabelDto copyWith({Map<String, dynamic>? value}) =>
      InboxTaskLabelDto(value ?? this.value);
  @override
  List<Object?> get props => [value];
}
