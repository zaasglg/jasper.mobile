import 'package:dio/dio.dart';

import '../../../../core/storage/workspace_selection_storage.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._dio, this._workspaceStorage);
  final Dio _dio;
  final WorkspaceSelectionStorage _workspaceStorage;

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
      ]);
      final channels = _items(responses[0].data);
      final users = _items(responses[1].data);
      final threads = _items(responses[2].data);
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
        ...users.whereType<Map>().map((item) {
          final json = Map<String, dynamic>.from(item);
          final id = json['id']?.toString() ?? '';
          return ChatConversationModel.fromUserJson(
            json,
            thread: _threadFor(threads, id, false),
          );
        }),
      ];
      return result.where((item) => item.id.isNotEmpty).toList(growable: false);
    } on DioException catch (error) {
      throw ChatException(_errorMessage(error, 'Не удалось загрузить чаты.'));
    }
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
          .where((item) => item.text.isNotEmpty)
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
      return ChatMessageModel.fromJson(payload);
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
    bool channel,
  ) {
    for (final item in threads.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
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
