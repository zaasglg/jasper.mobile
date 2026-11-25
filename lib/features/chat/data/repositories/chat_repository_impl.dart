import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/auth/auth_session.dart';
import '../models/channel_info_model.dart';
import '../../domain/repositories/channel_image_repository.dart';
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
        ChatOutboxRepository,
        ChannelImageRepository,
        ChannelMembersRepository,
        ChatActionsRepository,
        ChatInteractionRepository,
        ChatRefreshRepository,
        ChatThreadActionsRepository {
  ChatRepositoryImpl(this._dio, this._workspaceStorage);
  final Dio _dio;
  final WorkspaceSelectionStorage _workspaceStorage;
  final _outboxStorage = const FlutterSecureStorage();
  Future<void> _outboxWrites = Future.value();
  final _sendingClients = <String>{};

  Future<String> _outboxKey() async {
    final token = await _outboxStorage.read(key: 'access_token');
    if (token == null) throw const ChatException('Требуется авторизация.');
    final claims =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token.split('.')[1])),
              ),
            )
            as Map;
    final owner = claims['sub'] ?? claims['id'];
    if (owner == null) throw const ChatException('Требуется авторизация.');
    return 'chat_outbox.v1.$owner.${await _workspaceId()}';
  }

  Future<List<ChatMessageModel>> _readOutbox(String key) async {
    final raw = await _outboxStorage.read(key: key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> _savePending(
    String key,
    ChatMessageModel message, {
    bool remove = false,
  }) {
    final operation = _outboxWrites.then((_) async {
      final messages = await _readOutbox(key);
      messages.removeWhere((e) => e.clientId == message.clientId);
      if (!remove) messages.add(message);
      await _outboxStorage.write(
        key: key,
        value: jsonEncode(messages.map((e) => e.toJson()).toList()),
      );
    });
    _outboxWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<List<ChatMessageModel>> pendingMessages(String threadId) async {
    final key = await _outboxKey();
    await _outboxWrites;
    return (await _readOutbox(key))
        .where((e) => e.threadId == threadId)
        .map(
          (e) => e.copyWith(
            deliveryStatus: _sendingClients.contains(e.clientId)
                ? 'sending'
                : 'failed',
          ),
        )
        .toList();
  }

  @override
  Future<ChatMessageModel> enqueueMessage(String threadId, String text) async {
    final key = await _outboxKey();
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final message = ChatMessageModel(
      id: 'local:$id',
      clientId: id,
      threadId: threadId,
      authorId: '',
      authorName: '',
      text: text,
      createdAt: DateTime.now(),
      deliveryStatus: 'sending',
    );
    await _savePending(key, message);
    return message;
  }

  @override
  Future<ChatMessageModel> sendPending(ChatMessageModel message) async {
    final key = await _outboxKey();
    if (!_sendingClients.add(message.clientId!)) {
      throw const ChatException('Отправка уже выполняется.');
    }
    try {
      final user = await _dio.get<dynamic>('users/me');
      final userId = _object(user.data, const [
        'data',
        'user',
      ])['id']?.toString();
      if (userId == null || userId.trim().isEmpty) {
        throw const ChatException('Не удалось определить отправителя.');
      }
      final payload = <String, dynamic>{
        'clientId': message.clientId,
        'userId': userId,
        'threadId': message.threadId,
        'workspaceId': await _workspaceId(),
        'kind': 'TEXT',
        'text': message.text,
      };
      Future<Response<dynamic>> post() => _dio
          .post<dynamic>(
            'messages',
            options: Options(
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
            ),
            data: Map<String, dynamic>.of(payload),
          )
          .timeout(const Duration(seconds: 25));
      Response<dynamic> response;
      try {
        response = await post();
      } on DioException catch (error) {
        final data = error.response?.data;
        final errors = data is Map ? data['message'] : null;
        final messages = errors is List ? errors : [errors];
        // A validation rejection happens before creation. Never retry an
        // ambiguous failure without the server's deduplication identifier.
        if (error.response?.statusCode != 400 ||
            !messages.contains('property clientId should not exist')) {
          rethrow;
        }
        payload.remove('clientId');
        response = await post();
      }
      final result = ChatMessageModel.fromJson(
        _object(response.data, const ['data', 'message']),
      );
      if (result.id.isEmpty) {
        throw const ChatException('Некорректный ответ сервера.');
      }
      await _savePending(key, message, remove: true);
      return result;
    } catch (_) {
      await _savePending(key, message.copyWith(deliveryStatus: 'failed'));
      rethrow;
    } finally {
      _sendingClients.remove(message.clientId);
    }
  }

  final _images = <String, ChannelImageUpdate>{};
  final _imageWrites = <String, int>{};
  final _imageChanges = StreamController<ChannelImageUpdate>.broadcast(
    sync: true,
  );
  int _writeRevision = 0;
  int _imageRevision = DateTime.now().microsecondsSinceEpoch;
  int _imageSession = authSession.generation;
  void _checkImageSession() {
    if (_imageSession == authSession.generation) return;
    _imageSession = authSession.generation;
    _images.clear();
    _imageWrites.clear();
  }

  Future<void> dispose() => _imageChanges.close();
  @override
  Stream<ChannelImageUpdate> get channelImageChanges => _imageChanges.stream;
  @override
  ChannelImageUpdate? channelImageSnapshot(String channelId) {
    _checkImageSession();
    return _images[channelId];
  }

  String? _rememberImage(
    String id,
    String? url,
    int readRevision,
    int session, {
    bool saved = false,
  }) {
    _checkImageSession();
    if (session != _imageSession) return url;
    if (!saved && (_imageWrites[id] ?? 0) > readRevision) {
      return _images[id]?.imageUrl;
    }
    if (saved) _imageWrites[id] = ++_writeRevision;
    if (saved || !_images.containsKey(id) || _images[id]!.imageUrl != url) {
      final update = ChannelImageUpdate(id, url, ++_imageRevision);
      _images[id] = update;
      if (!_imageChanges.isClosed) _imageChanges.add(update);
    }
    return url;
  }

  @override
  Future<ChannelInfoModel> channelInfo(String channelId) async {
    _checkImageSession();
    final revision = _writeRevision, session = _imageSession;
    try {
      final response = await _dio.get<dynamic>(
        'channels/${Uri.encodeComponent(channelId)}/members',
      );
      final json = _object(response.data, const ['data']);
      if (json['members'] is! List) {
        throw const ChannelPhotoException(ChannelPhotoError.invalidResponse);
      }
      final info = ChannelInfoModel.fromJson(json);
      return info.copyWith(
        imageUrl: _rememberImage(channelId, info.imageUrl, revision, session),
      );
    } on DioException catch (e) {
      throw ChannelPhotoException(
        e.response?.statusCode == 403
            ? ChannelPhotoError.forbidden
            : ChannelPhotoError.load,
      );
    }
  }

  @override
  Future<String?> setChannelImage(String channelId, String? dataUrl) async {
    if (dataUrl != null &&
        (dataUrl.length > 100000 ||
            !RegExp(
              r'^data:image/(jpeg|webp);base64,[A-Za-z0-9+/]+={0,2}$',
            ).hasMatch(dataUrl))) {
      throw const ChannelPhotoException(ChannelPhotoError.format);
    }
    _checkImageSession();
    final session = _imageSession;
    try {
      final response = await _dio.patch<dynamic>(
        'channels/${Uri.encodeComponent(channelId)}',
        data: {'imageUrl': dataUrl},
      );
      final json = response.data is Map
          ? _object(response.data, const ['data', 'channel'])
          : <String, dynamic>{};
      final value = json.containsKey('imageUrl') ? json['imageUrl'] : dataUrl;
      if (value != null && value is! String) {
        throw const ChannelPhotoException(ChannelPhotoError.invalidResponse);
      }
      final url = value as String?;
      _rememberImage(channelId, url, _writeRevision, session, saved: true);
      return url;
    } on DioException catch (e) {
      throw ChannelPhotoException(
        e.response?.statusCode == 403
            ? ChannelPhotoError.forbidden
            : ChannelPhotoError.save,
      );
    }
  }

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
  Future<void> deleteConversation(String threadId) async {
    if (!threadId.startsWith('dm:')) {
      throw const ChatException('Удалять можно только личные чаты.');
    }
    await _action(
      'POST',
      'messages/threads/clear',
      data: {
        'threadId': threadId,
        'workspaceId': await _workspaceId(),
        'keepVisible': false,
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
  Future<List<SpaceMember>> workspaceChannelCandidates() async {
    final workspaceId = await _workspaceId();
    try {
      final response = await _dio.get<dynamic>(
        'workspaces/${Uri.encodeComponent(workspaceId)}/members',
      );
      if (response.data is! List && response.data is! Map) {
        throw const ChatException(
          'Не удалось загрузить участников воркспейса.',
        );
      }
      return _items(response.data)
          .whereType<Map>()
          .map(
            (json) => SpaceMemberDto.fromJson(
              Map<String, dynamic>.from(json),
            ).toEntity(),
          )
          .where((member) => member.userId.isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw ChatException(
        _errorMessage(error, 'Не удалось загрузить участников воркспейса.'),
      );
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
    _checkImageSession();
    final imageRevision = _writeRevision, imageSession = _imageSession;
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
          final parsed = ChatConversationModel.fromChannelJson(json);
          final channel = parsed.copyWith(
            imageUrl: _rememberImage(
              parsed.id,
              parsed.imageUrl,
              imageRevision,
              imageSession,
            ),
          );
          final thread = _threadFor(threads, channel.id, true);
          return thread == null
              ? channel
              : channel.copyWith(
                  threadId: _threadId(thread) ?? channel.threadId,
                  unreadCount: _unread(thread),
                  lastMessage: ChatConversationModel.previewFromThread(
                    thread,
                    currentUserId: currentUserId,
                  ),
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
    final expected = channel
        ? targetId
        : currentUserId == null
        ? null
        : ChatConversationModel.directThreadId(currentUserId, targetId);
    // A thread summary's `user` is its last author, not the DM recipient.
    // Match canonical IDs before considering older participant-based shapes.
    if (expected != null) {
      for (final item in threads.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        if (_threadId(map) == expected) return map;
      }
    }
    for (final item in threads.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final isHead = map.containsKey('text') || map.containsKey('lastMessage');
      final candidateIds = channel
          ? [
              map['channelId'],
              (map['channel'] is Map ? (map['channel'] as Map)['id'] : null),
            ]
          : [
              map['recipientId'],
              map['otherUserId'],
              if (!isHead) map['userId'],
              if (!isHead && map['user'] is Map) (map['user'] as Map)['id'],
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
