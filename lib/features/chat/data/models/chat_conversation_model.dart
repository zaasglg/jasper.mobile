import 'chat_message_preview_model.dart';
import 'package:equatable/equatable.dart';

class ChatConversationModel extends Equatable {
  const ChatConversationModel({
    required this.id,
    required this.threadId,
    required this.title,
    required this.isChannel,
    this.avatarUrl,
    this.imageUrl,
    this.parentId,
    this.isOnline = false,
    this.unreadCount = 0,
    this.hasThread = false,
    this.lastMessage,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) =>
      ChatConversationModel(
        id: json['id'] as String? ?? '',
        threadId: json['threadId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        isChannel: json['isChannel'] == true,
        avatarUrl: json['avatarUrl'] as String?,
        imageUrl: json['imageUrl'] as String?,
        parentId: json['parentId'] as String?,
        isOnline: json['isOnline'] == true,
        unreadCount: _integer(json, const ['unreadCount']),
        hasThread: json['hasThread'] == true,
        lastMessage: json['lastMessage'] is Map
            ? ChatMessagePreviewModel.fromJson(
                Map<String, dynamic>.from(json['lastMessage'] as Map),
              )
            : null,
      );

  factory ChatConversationModel.fromChannelJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    return ChatConversationModel(
      id: id,
      threadId: _string(json, const ['threadId', 'thread_id']) ?? id,
      title: _string(json, const ['name', 'title']) ?? 'Канал',
      isChannel: true,
      imageUrl: _string(json, const ['imageUrl']),
      parentId: _string(json, const ['parentId', 'parent_id']),
      unreadCount: _integer(json, const ['unreadCount', 'unread_count']),
    );
  }

  factory ChatConversationModel.fromUserJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? thread,
    String? currentUserId,
  }) {
    final id = json['id']?.toString() ?? '';
    return ChatConversationModel(
      id: id,
      threadId:
          _string(thread ?? json, const ['threadId', 'thread_id']) ??
          (currentUserId == null ? '' : directThreadId(currentUserId, id)),
      title:
          _string(json, const ['name', 'fullName', 'full_name', 'email']) ??
          'Пользователь',
      isChannel: false,
      hasThread: thread != null,
      lastMessage: previewFromThread(thread, currentUserId: currentUserId),
      avatarUrl: _string(json, const ['avatarUrl', 'avatar_url', 'avatar']),
      isOnline: json['online'] == true || json['isOnline'] == true,
      unreadCount: _integer(thread ?? json, const [
        'unreadCount',
        'unread_count',
      ]),
    );
  }

  static ChatMessagePreviewModel? previewFromThread(
    Map<String, dynamic>? thread, {
    String? currentUserId,
  }) =>
      thread != null &&
          (thread.containsKey('text') || thread['lastMessage'] is Map)
      ? ChatMessagePreviewModel.fromThreadJson(
          thread,
          currentUserId: currentUserId,
        )
      : null;

  static String directThreadId(String currentUserId, String recipientId) {
    final participants = [currentUserId, recipientId]..sort();
    return 'dm:${participants.join(":")}';
  }

  final String id;
  final String threadId;
  final String title;
  final bool isChannel;
  final String? avatarUrl;
  final String? imageUrl;
  final String? parentId;
  final bool isOnline;
  final int unreadCount;
  final bool hasThread;
  final ChatMessagePreviewModel? lastMessage;

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
    'imageUrl': imageUrl,
    'parentId': parentId,
    'isOnline': isOnline,
    'unreadCount': unreadCount,
    'hasThread': hasThread,
    'lastMessage': lastMessage?.toJson(),
  };

  static const _unchanged = Object();
  ChatConversationModel copyWith({
    String? threadId,
    int? unreadCount,
    Object? imageUrl = _unchanged,
    Object? lastMessage = _unchanged,
  }) {
    return ChatConversationModel(
      id: id,
      threadId: threadId ?? this.threadId,
      title: title,
      isChannel: isChannel,
      avatarUrl: avatarUrl,
      imageUrl: identical(imageUrl, _unchanged)
          ? this.imageUrl
          : imageUrl as String?,
      parentId: parentId,
      isOnline: isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      hasThread: hasThread,
      lastMessage: identical(lastMessage, _unchanged)
          ? this.lastMessage
          : lastMessage as ChatMessagePreviewModel?,
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
    imageUrl,
    parentId,
    isOnline,
    unreadCount,
    hasThread,
    lastMessage,
  ];
}
