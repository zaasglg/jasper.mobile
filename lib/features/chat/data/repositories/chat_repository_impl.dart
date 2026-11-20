import '../../../collaboration/data/models/space_member_dto.dart';
import '../../../collaboration/domain/entities/space_member.dart';
import 'package:dio/dio.dart';

import '../../../../core/storage/workspace_selection_storage.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_interaction_models.dart';

class ChatRepositoryImpl
    implements
        ChatRepository,
        ChatActionsRepository,
        ChatInteractionRepository,
        ChatRefreshRepository,
        ChatThreadActionsRepository {
  const ChatRepositoryImpl(this._dio, this._workspaceStorage);
  final Dio _dio;
  final WorkspaceSelectionStorage _workspaceStorage;
  @override
  Future<void> clearConversation(String threadId) async {
    final workspaceId = await _workspaceId();
    await _action(
      'POST',
      'messages/threads/clear',
      data: {
        'threadId': threadId,
        'workspaceId': workspaceId,
        'keepVisible': true,
      },
    );
  }

  @override
  Future<String> interactionWorkspaceId() => _workspaceId();
  @override
  Future<List<ChatTypingUser>> typing(
    String threadId,
    String workspaceId,
  ) async {
    final response = await _dio.get<dynamic>(
      'messages/typing',
      queryParameters: {'threadId': threadId, 'workspaceId': workspaceId},
    );
    return _items(response.data)
        .whereType<Map>()
        .map((e) => ChatTypingUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<void> updateTyping(String threadId, String workspaceId, bool typing) =>
      _action(
        'POST',
        'messages/typing',
        data: {
          'threadId': threadId,
          'workspaceId': workspaceId,
          'typing': typing,
        },
      );
  Future<ChatMessageModel> _interaction(
    String id,
    String action, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'messages/${Uri.encodeComponent(id)}/$action',
        data: data,
      );
      return ChatMessageModel.fromJson(
        _object(response.data, const ['data', 'message']),
      );
    } on DioException catch (error) {
      throw ChatException(
        _errorMessage(error, 'Не удалось сохранить действие.'),
      );
    }
  }

  @override
  Future<ChatMessageModel> togglePin(String id) => _interaction(id, 'pin');
  @override
  Future<ChatMessageModel> react(String id, String emoji) =>
      _interaction(id, 'react', data: {'emoji': emoji});
  @override
  Future<ChatMessageModel> forwardMessage(
    ChatMessageModel message,
    ChatConversationModel target,
  ) async {
    if (message.kind == ChatMessageKind.audio) {
      final transcript = message.transcript ?? '';
      final uri = Uri.tryParse(transcript);
      if (!transcript.startsWith('data:audio/') &&
          !(uri?.scheme == 'https' && uri!.host.isNotEmpty)) {
        throw const ChatException('Аудиозапись недоступна для пересылки.');
      }
    }
    String? attachment = message.attachmentDataUrl;
    if (attachment == null &&
        (message.isFile || message.kind == ChatMessageKind.videoMessage)) {
      try {
        final response = await _dio.get<dynamic>(
          'messages/${Uri.encodeComponent(message.id)}/attachment',
        );
        attachment = _object(response.data, const [
          'data',
        ])['dataUrl']?.toString();
        if (attachment == null || attachment.isEmpty) {
          throw const ChatException('Вложение недоступно для пересылки.');
        }
      } on DioException catch (error) {
        throw ChatException(
          _errorMessage(error, 'Не удалось загрузить вложение.'),
        );
      }
    }
    return sendMessage(
      conversation: target,
      text: message.isFile || message.kind == ChatMessageKind.videoMessage
          ? message.text
          : '↪ ${message.text}',
      kind: message.kind == ChatMessageKind.audio
          ? ChatMessageKind.audio
          : ChatMessageKind.text,
      transcript: message.kind == ChatMessageKind.audio
          ? message.transcript
          : null,
      duration: message.durationSeconds,
      mention: attachment,
    );
  }

  Future<void> _action(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
      );
    } on DioException catch (error) {
      throw ChatException(
        _errorMessage(
          error,
          error.response?.statusCode == 403
              ? 'Недостаточно прав для этого действия.'
              : 'Не удалось выполнить действие.',
        ),
      );
    }
  }

  @override
  Future<void> toggleFavorite(String messageId) =>
      _action('POST', 'messages/${Uri.encodeComponent(messageId)}/favorite');
  @override
  Future<void> editMessage(String messageId, String text) => _action(
    'PATCH',
    'messages/${Uri.encodeComponent(messageId)}',
    data: {'text': text.trim()},
  );
  @override
  Future<void> deleteMessage(String messageId) =>
      _action('DELETE', 'messages/${Uri.encodeComponent(messageId)}');
  @override
  Future<void> markRead(String threadId) async => _action(
    'POST',
    'messages/threads/read',
    data: {'threadId': threadId, 'workspaceId': await _workspaceId()},
  );
  @override
  Future<void> renameChannel(String channelId, String name) => _action(
    'PATCH',
    'channels/${Uri.encodeComponent(channelId)}',
    data: {'name': name.trim()},
  );
  @override
  Future<void> leaveChannel(String channelId) => _action(
    'DELETE',
    'channels/${Uri.encodeComponent(channelId)}/members/me',
  );
  @override
  Future<void> deleteChannel(String channelId) =>
      _action('DELETE', 'channels/${Uri.encodeComponent(channelId)}');
  @override
  Future<List<SpaceMember>> channelMembers(String channelId) async {
    try {
      return _items(
            (await _dio.get<dynamic>(
              'channels/${Uri.encodeComponent(channelId)}/members',
            )).data,
          )
          .whereType<Map>()
          .map(
            (e) => SpaceMemberDto.fromJson(
              Map<String, dynamic>.from(e),
            ).toEntity(),
          )
          .toList();
    } on DioException {
      throw const ChatException('Не удалось загрузить участников канала.');
    }
  }

  @override
  Future<void> setChannelMembers(String channelId, List<String> userIds) =>
      _action(
        'PUT',
        'channels/${Uri.encodeComponent(channelId)}/members',
        data: {'memberIds': userIds},
      );

  @override
  Future<List<ChatConversationModel>> getConversations() async {
    final workspaceId = await _workspaceId();
    try {
      final responses = await Future.wait([
        _dio.get<dynamic>(
          'channels',
          queryParameters: {'workspaceId': workspaceId},
        ),
        _dio.get<dynamic>(
          'users/messenger-candidates',
          queryParameters: {'workspaceId': workspaceId},
        ),
        _dio.get<dynamic>(
          'messages/threads',
          queryParameters: {'workspaceId': workspaceId},
        ),
        _dio.get<dynamic>('users/me'),
      ]);
      final currentUserId = _object(responses[3].data, const [
        'data',
        'user',
      ])['id']?.toString();
      if (currentUserId == null || currentUserId.trim().isEmpty) {
        throw const ChatException(
          'Не удалось определить текущего пользователя.',
        );
      }
      final channels = _items(responses[0].data);
      final users = _items(responses[1].data);
      final threads = _items(responses[2].data);
      try {
        if (threads.isNotEmpty) {
          final unreadResponse = await _dio.post<dynamic>(
            'messages/unread-per-thread',
            data: {
              'workspaceId': workspaceId,
              'threads': [
                for (final raw in threads.whereType<Map>())
                  {
                    'threadId': _threadId(Map<String, dynamic>.from(raw)),
                    'since': 0,
                  },
              ],
            },
          );
          final unreadData = unreadResponse.data;
          final counts = unreadData is Map ? unreadData['counts'] : null;
          if (counts is Map) {
            for (final thread in threads.whereType<Map>()) {
              thread['unreadCount'] =
                  counts[_threadId(Map<String, dynamic>.from(thread))] ?? 0;
            }
          }
        }
      } on DioException {
        /* Keep chats available when unread counts cannot be refreshed. */
      }
      final result = <ChatConversationModel>[
        ...channels.whereType<Map>().map((item) {
          final json = Map<String, dynamic>.from(item);
          final channel = ChatConversationModel.fromChannelJson(json);
          final thread = _threadFor(threads, channel.id, true);
          return thread == null
              ? channel
              : channel.copyWith(
                  threadId: _threadId(thread) ?? channel.threadId,
                  unreadCount: _unread(thread),
                );
        }),
        ...users
            .whereType<Map>()
            .where((item) => item['id']?.toString() != currentUserId)
            .where((item) => item['isActive'] != false)
            .map((item) {
              final json = Map<String, dynamic>.from(item);
              final id = json['id']?.toString() ?? '';
              return ChatConversationModel.fromUserJson(
                json,
                thread: _threadFor(threads, id, false, currentUserId),
                currentUserId: currentUserId,
              );
            }),
      ];
      return result.where((item) => item.id.isNotEmpty).toList(growable: false);
    } on DioException catch (error) {
      throw ChatException(_errorMessage(error, 'Не удалось загрузить чаты.'));
    }
  }

  @override
  Future<List<ChatMessageModel>> refreshMessages(
    String threadId,
    List<ChatMessageModel> previous,
  ) async {
    if (previous.isEmpty) return getMessages(threadId);
    final workspaceId = await _workspaceId();
    final known = previous.map((message) => message.id).toSet();
    final recent = <String, ChatMessageModel>{};
    final cursors = <String>{};
    String? cursor;
    bool reachedStart = false;
    try {
      while (true) {
        final response = await _dio.get<dynamic>(
          'messages',
          queryParameters: {
            'threadId': threadId,
            'workspaceId': workspaceId,
            'take': 100,
            'direction': 'backward',
            'cursor': ?cursor,
          },
        );
        final page = _items(response.data)
            .whereType<Map>()
            .map(
              (raw) =>
                  ChatMessageModel.fromJson(Map<String, dynamic>.from(raw)),
            )
            .toList();
        for (final message in page) {
          recent[message.id] = message;
        }
        final raw = response.data;
        final envelope = raw is Map && raw['data'] is Map
            ? raw['data'] as Map
            : raw;
        final next = envelope is Map
            ? envelope['nextCursor']?.toString()
            : null;
        reachedStart = next == null;
        if (reachedStart || page.any((message) => known.contains(message.id))) {
          break;
        }
        if (!cursors.add(next)) {
          throw const ChatException('Сервер повторил страницу сообщений.');
        }
        cursor = next;
      }
      final fresh = recent.values.toList()..sort(_compareMessages);
      if (fresh.isEmpty) return [];
      final merged = <String, ChatMessageModel>{
        if (!reachedStart)
          for (final message in previous)
            if (_compareMessages(message, fresh.first) < 0) message.id: message,
        for (final message in fresh)
          if (message.text.isNotEmpty || message.kind != ChatMessageKind.text)
            message.id: message,
      };
      return merged.values.toList()..sort(_compareMessages);
    } on DioException catch (error) {
      throw ChatException(
        _errorMessage(error, 'Не удалось обновить сообщения.'),
      );
    }
  }

  static int _compareMessages(ChatMessageModel a, ChatMessageModel b) {
    final date = a.createdAt.compareTo(b.createdAt);
    return date == 0 ? a.id.compareTo(b.id) : date;
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) async {
    final workspaceId = await _workspaceId();
    try {
      final response = await _dio.get<dynamic>(
        'messages',
        queryParameters: {'threadId': threadId, 'workspaceId': workspaceId},
      );
      return _items(response.data)
          .whereType<Map>()
          .map(
            (item) =>
                ChatMessageModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (item) => item.text.isNotEmpty || item.kind != ChatMessageKind.text,
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ChatException(
        _errorMessage(error, 'Не удалось загрузить сообщения.'),
      );
    }
  }

  @override
  Future<ChatConversationModel> createChannel({
    required String name,
    String? parentId,
  }) async {
    final workspaceId = await _workspaceId();
    try {
      final response = await _dio.post<dynamic>(
        'channels',
        data: <String, dynamic>{
          'name': name.trim(),
          'workspaceId': workspaceId,
          'memberIds': const <String>[],
          'parentId': ?parentId,
        },
      );
      return ChatConversationModel.fromChannelJson(
        _object(response.data, const ['data', 'channel']),
      );
    } on DioException catch (error) {
      throw ChatException(_errorMessage(error, 'Не удалось создать канал.'));
    }
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required ChatConversationModel conversation,
    required String text,
    ChatMessageKind kind = ChatMessageKind.text,
    String? transcript,
    String? mention,
    int? duration,
  }) async {
    final workspaceId = await _workspaceId();
    try {
      final user = await _dio.get<dynamic>('users/me');
      final userId = _object(user.data, const [
        'data',
        'user',
      ])['id']?.toString();
      if (userId == null || userId.trim().isEmpty) {
        throw const ChatException('Не удалось определить отправителя.');
      }
      final response = await _dio.post<dynamic>(
        'messages',
        options: transcript == null
            ? null
            : Options(
                sendTimeout: const Duration(minutes: 2),
                receiveTimeout: const Duration(minutes: 2),
              ),
        data: <String, dynamic>{
          'text': text,
          'kind': kind.name.toUpperCase(),
          'userId': userId,
          'transcript': ?transcript,
          'mention': ?mention,
          'duration': ?duration,
          'workspaceId': workspaceId,
          'threadId': conversation.threadId,
        },
      );
      final payload = _object(response.data, const ['data', 'message']);
      return ChatMessageModel.fromJson({
        ...payload,
        // The API may omit media bytes from the response after storing them.
        if (payload['mention'] == null && mention != null) 'mention': mention,
        if (payload['transcript'] == null && transcript != null)
          'transcript': transcript,
      });
    } on DioException catch (error) {
      throw ChatException(
        _errorMessage(error, 'Не удалось отправить сообщение.'),
      );
    }
  }

  Future<String> _workspaceId() async {
    final id = await _workspaceStorage.read();
    if (id == null || id.isEmpty) {
      throw const ChatException('Сначала выберите workspace.');
    }
    return id;
  }

  List<dynamic> _items(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in const [
        'data',
        'items',
        'channels',
        'members',
        'users',
        'threads',
        'messages',
      ]) {
        final value = map[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = Map<String, dynamic>.from(value);
          for (final nestedKey in const [
            'items',
            'channels',
            'members',
            'users',
            'threads',
            'messages',
          ]) {
            if (nested[nestedKey] is List) {
              return nested[nestedKey] as List<dynamic>;
            }
          }
        }
      }
    }
    return const [];
  }

  Map<String, dynamic> _object(dynamic data, List<String> keys) {
    if (data is! Map) {
      throw const ChatException('Сервер вернул некорректное сообщение.');
    }
    final map = Map<String, dynamic>.from(data);
    for (final key in keys) {
      if (map[key] is Map) return Map<String, dynamic>.from(map[key] as Map);
    }
    return map;
  }

  Map<String, dynamic>? _threadFor(
    List<dynamic> threads,
    String targetId,
    bool channel, [
    String? currentUserId,
  ]) {
    for (final item in threads.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      if (!channel &&
          currentUserId != null &&
          _threadId(map) ==
              ChatConversationModel.directThreadId(currentUserId, targetId)) {
        return map;
      }
      final candidateIds = channel
          ? [
              map['channelId'],
              (map['channel'] is Map ? (map['channel'] as Map)['id'] : null),
            ]
          : [
              map['userId'],
              map['recipientId'],
              map['otherUserId'],
              (map['user'] is Map ? (map['user'] as Map)['id'] : null),
            ];
      if (candidateIds.any((id) => id?.toString() == targetId)) return map;
    }
    return null;
  }

  String? _threadId(Map<String, dynamic> thread) =>
      (thread['threadId'] ?? thread['id'])?.toString();
  int _unread(Map<String, dynamic> thread) =>
      int.tryParse(
        (thread['unreadCount'] ?? thread['unread_count'] ?? 0).toString(),
      ) ??
      0;

  String _errorMessage(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Нет подключения к интернету.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Сервер не отвечает. Попробуйте ещё раз.';
    }
    return fallback;
  }
}
