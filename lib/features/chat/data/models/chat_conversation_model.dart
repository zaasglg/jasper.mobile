import 'package:equatable/equatable.dart';

class ChatConversationModel extends Equatable {
  const ChatConversationModel({
    required this.id,
    required this.threadId,
    required this.title,
    required this.isChannel,
    this.avatarUrl,
    this.parentId,
    this.isOnline = false,
    this.unreadCount = 0,
  });

  factory ChatConversationModel.fromChannelJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    return ChatConversationModel(
      id: id,
      threadId: _string(json, const ['threadId', 'thread_id']) ?? id,
      title: _string(json, const ['name', 'title']) ?? 'Канал',
      isChannel: true,
      parentId: _string(json, const ['parentId', 'parent_id']),
      unreadCount: _integer(json, const ['unreadCount', 'unread_count']),
    );
  }

  factory ChatConversationModel.fromUserJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? thread,
  }) {
    final id = json['id']?.toString() ?? '';
    return ChatConversationModel(
      id: id,
      threadId:
          _string(thread ?? json, const ['threadId', 'thread_id', 'id']) ?? id,
      title:
          _string(json, const ['name', 'fullName', 'full_name', 'email']) ??
          'Пользователь',
      isChannel: false,
      avatarUrl: _string(json, const ['avatarUrl', 'avatar_url', 'avatar']),
      isOnline: json['online'] == true || json['isOnline'] == true,
      unreadCount: _integer(thread ?? json, const [
        'unreadCount',
        'unread_count',
      ]),
    );
  }

  final String id;
  final String threadId;
  final String title;
  final bool isChannel;
  final String? avatarUrl;
  final String? parentId;
  final bool isOnline;
  final int unreadCount;

  String get initials {
    final words = title.trim().split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0])
        .join()
        .toUpperCase();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'threadId': threadId,
    'title': title,
    'isChannel': isChannel,
    'avatarUrl': avatarUrl,
    'parentId': parentId,
    'isOnline': isOnline,
    'unreadCount': unreadCount,
  };

  ChatConversationModel copyWith({String? threadId, int? unreadCount}) {
    return ChatConversationModel(
      id: id,
      threadId: threadId ?? this.threadId,
      title: title,
      isChannel: isChannel,
      avatarUrl: avatarUrl,
      parentId: parentId,
      isOnline: isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  static String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static int _integer(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  @override
  List<Object?> get props => [
    id,
    threadId,
    title,
    isChannel,
    avatarUrl,
    parentId,
    isOnline,
    unreadCount,
  ];
}
