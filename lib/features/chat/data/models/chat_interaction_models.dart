import 'package:equatable/equatable.dart';

class ChatReaction extends Equatable {
  const ChatReaction({
    required this.emoji,
    required this.count,
    this.reacted = false,
    this.authors = const [],
  });
  final String emoji;
  final int count;
  final bool reacted;
  final List<String> authors;
  factory ChatReaction.fromJson(Map<String, dynamic> json) => ChatReaction(
    emoji: json['emoji']?.toString() ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    reacted: json['reacted'] == true,
    authors: (json['authors'] as List? ?? []).map((e) => e.toString()).toList(),
  );
  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'count': count,
    'reacted': reacted,
    'authors': authors,
  };
  ChatReaction copyWith({
    String? emoji,
    int? count,
    bool? reacted,
    List<String>? authors,
  }) => ChatReaction(
    emoji: emoji ?? this.emoji,
    count: count ?? this.count,
    reacted: reacted ?? this.reacted,
    authors: authors ?? this.authors,
  );
  @override
  List<Object?> get props => [emoji, count, reacted, authors];
}

class ChatTypingUser extends Equatable {
  const ChatTypingUser({required this.userId, required this.name});
  final String userId, name;
  factory ChatTypingUser.fromJson(Map<String, dynamic> json) => ChatTypingUser(
    userId: json['userId']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Участник',
  );
  Map<String, dynamic> toJson() => {'userId': userId, 'name': name};
  ChatTypingUser copyWith({String? userId, String? name}) =>
      ChatTypingUser(userId: userId ?? this.userId, name: name ?? this.name);
  @override
  List<Object?> get props => [userId, name];
}
