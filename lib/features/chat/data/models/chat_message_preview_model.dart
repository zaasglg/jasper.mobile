import 'package:equatable/equatable.dart';
import 'chat_message_model.dart';

/// A thread head from /messages/threads, without loading conversation history.
class ChatMessagePreviewModel extends Equatable {
  const ChatMessagePreviewModel({
    required this.text,
    this.authorName,
    this.isOwn = false,
    this.kind = ChatMessageKind.text,
  });
  factory ChatMessagePreviewModel.fromJson(Map<String, dynamic> json) =>
      ChatMessagePreviewModel(
        text: json['text'] is String ? json['text'] as String : '',
        authorName: json['authorName'] as String?,
        isOwn: json['isOwn'] == true,
        kind: ChatMessageKind.values.firstWhere(
          (kind) => kind.name == json['kind'],
          orElse: () => ChatMessageKind.unknown,
        ),
      );
  factory ChatMessagePreviewModel.fromThreadJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final source = json['lastMessage'] is Map
        ? Map<String, dynamic>.from(json['lastMessage'] as Map)
        : json;
    final message = ChatMessageModel.fromJson(source);
    final author = source['user'] ?? source['author'] ?? source['sender'];
    final name = author is Map ? author['name'] : source['authorName'];
    var text = (message.quote?.body ?? message.text)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length > 500) text = text.substring(0, 500);
    return ChatMessagePreviewModel(
      text: text,
      authorName: name is String && name.trim().isNotEmpty ? name.trim() : null,
      isOwn:
          currentUserId != null &&
          currentUserId.isNotEmpty &&
          message.authorId == currentUserId,
      kind: message.kind,
    );
  }
  final String text;
  final String? authorName;
  final bool isOwn;
  final ChatMessageKind kind;
  Map<String, dynamic> toJson() => {
    'text': text,
    'authorName': authorName,
    'isOwn': isOwn,
    'kind': kind.name,
  };
  ChatMessagePreviewModel copyWith({
    String? text,
    String? authorName,
    bool? isOwn,
    ChatMessageKind? kind,
  }) => ChatMessagePreviewModel(
    text: text ?? this.text,
    authorName: authorName ?? this.authorName,
    isOwn: isOwn ?? this.isOwn,
    kind: kind ?? this.kind,
  );
  @override
  List<Object?> get props => [text, authorName, isOwn, kind];
}
