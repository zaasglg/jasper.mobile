import 'package:equatable/equatable.dart';

class DailyQuote extends Equatable {
  const DailyQuote({
    required this.text,
    required this.author,
    this.refreshing = false,
  });
  final String text, author;
  final bool refreshing;

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    final quote = json['quote'];
    if (quote is! Map ||
        quote['text'] is! String ||
        quote['author'] is! String ||
        (quote['text'] as String).trim().isEmpty ||
        (quote['author'] as String).trim().isEmpty) {
      throw const FormatException('Некорректная цитата дня');
    }
    return DailyQuote(
      text: (quote['text'] as String).trim(),
      author: (quote['author'] as String).trim(),
      refreshing: json['refreshing'] == true,
    );
  }
  Map<String, dynamic> toJson() => {
    'quote': {'text': text, 'author': author},
    'refreshing': refreshing,
  };
  DailyQuote copyWith({String? text, String? author, bool? refreshing}) =>
      DailyQuote(
        text: text ?? this.text,
        author: author ?? this.author,
        refreshing: refreshing ?? this.refreshing,
      );
  @override
  List<Object?> get props => [text, author, refreshing];
}
