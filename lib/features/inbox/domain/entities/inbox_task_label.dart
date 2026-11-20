import 'package:equatable/equatable.dart';

class InboxTaskLabel extends Equatable {
  const InboxTaskLabel({this.id, this.text, this.color});
  final String? id, text, color;
  InboxTaskLabel copyWith({String? id, String? text, String? color}) =>
      InboxTaskLabel(
        id: id ?? this.id,
        text: text ?? this.text,
        color: color ?? this.color,
      );
  @override
  List<Object?> get props => [id, text, color];
}
