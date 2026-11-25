import 'dart:convert';
import '../../chat/data/models/chat_message_model.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import '../../../core/storage/workspace_selection_storage.dart';
import '../../../core/utils/html_text.dart';

enum ActivityKind { notifications, discussions, mentions, saved }

class ActivityEntry extends Equatable {
  const ActivityEntry({
    required this.id,
    required this.text,
    required this.title,
    this.threadId,
    this.taskId,
    this.createdAt,
    this.authorId,
    this.avatarUrl,
  });
  final String id, text, title;
  final String? threadId, taskId;
  final String? authorId, avatarUrl;
  final DateTime? createdAt;
  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    final nested = json['message'];
    final message = nested is Map ? Map<String, dynamic>.from(nested) : json;
    final user = json['user'];
    final channel = message['channel'];
    final rawText = message['text']?.toString() ?? '';
    final plainText = htmlToPlainText(rawText);
    // Thread heads, mentions and reactions share the messenger call contract.
    // Parse only preview fields so unrelated message metadata cannot break the list.
    final preview = ChatMessageModel.fromJson({
      'text': rawText,
      'kind': message['kind'] ?? message['type'],
    });
    var callEvent =
        (message['kind'] ?? message['type'])?.toString().toUpperCase() ==
        'CALL';
    if (!callEvent && rawText.trimLeft().startsWith('{')) {
      try {
        final payload = jsonDecode(rawText);
        callEvent =
            payload is Map &&
            payload['callId'] is String &&
            (payload['callId'] as String).trim().isNotEmpty;
      } on FormatException {
        // A user's partial JSON remains text unless the message is typed CALL.
      }
    }
    return ActivityEntry(
      id: json['id']?.toString() ?? message['threadId']?.toString() ?? '',
      title: [
        json['emoji'],
        user is Map ? user['name'] : null,
        channel is Map ? channel['name'] : json['projectName'],
      ].whereType<String>().join(' · '),
      authorId: user is Map ? user['id']?.toString() : null,
      avatarUrl: user is Map
          ? (user['avatarUrl'] ?? user['avatar'])?.toString()
          : null,
      text: callEvent && preview.isCall ? preview.callHeading : plainText,
      threadId: message['threadId']?.toString(),
      taskId: json['taskId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'title': title,
    'threadId': threadId,
    'taskId': taskId,
    'createdAt': createdAt?.toIso8601String(),
    'authorId': authorId,
    'avatarUrl': avatarUrl,
  };
  ActivityEntry copyWith({
    String? id,
    String? text,
    String? title,
    String? threadId,
    String? taskId,
    DateTime? createdAt,
    String? authorId,
    String? avatarUrl,
  }) => ActivityEntry(
    id: id ?? this.id,
    text: text ?? this.text,
    title: title ?? this.title,
    threadId: threadId ?? this.threadId,
    taskId: taskId ?? this.taskId,
    createdAt: createdAt ?? this.createdAt,
    authorId: authorId ?? this.authorId,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );
  @override
  List<Object?> get props => [
    id,
    text,
    title,
    threadId,
    taskId,
    createdAt,
    authorId,
    avatarUrl,
  ];
}

class ActivityRepository {
  const ActivityRepository(this.dio, this.selection);
  final Dio dio;
  final WorkspaceSelectionStorage selection;
  List<Map<String, dynamic>> _items(dynamic data) {
    if (data is Map) {
      for (final key in ['data', 'items', 'messages', 'threads']) {
        if (data[key] is List || data[key] is Map) return _items(data[key]);
      }
    }
    if (data is! List) {
      throw const FormatException('Некорректный ответ сервера');
    }
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>?> _saved(
    Map<String, dynamic> params,
  ) async {
    final items = <Map<String, dynamic>>[];
    String? cursor;
    final seen = <String>{};
    try {
      do {
        final response = await dio.get<dynamic>(
          'messages/favorites',
          queryParameters: {...params, 'take': 100, 'cursor': ?cursor},
        );
        items.addAll(_items(response.data));
        final raw = response.data;
        cursor = raw is Map ? raw['nextCursor']?.toString() : null;
        if (cursor != null && !seen.add(cursor)) {
          throw const FormatException('Не удалось загрузить продолжение.');
        }
      } while (cursor != null && cursor.isNotEmpty);
      return items;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && items.isEmpty) return null;
      rethrow;
    }
  }

  Future<List<ActivityEntry>> load(ActivityKind kind) async {
    final workspaceId = await selection.read();
    if (workspaceId == null) return [];
    final params = {'workspaceId': workspaceId};
    final items = <Map<String, dynamic>>[];
    if (kind == ActivityKind.saved) {
      final saved = await _saved(params);
      if (saved != null) return saved.map(ActivityEntry.fromJson).toList();
    }

    if (kind == ActivityKind.notifications || kind == ActivityKind.mentions) {
      final result = await Future.wait([
        dio.get<dynamic>('dashboard/mentions', queryParameters: params),
        dio.get<dynamic>('dashboard/reactions', queryParameters: params),
      ]);
      for (var i = 0; i < result.length; i++) {
        items.addAll(
          _items(result[i].data).map(
            (item) => {
              ...item,
              'id': '${i == 0 ? 'mention' : 'reaction'}:${item['id']}',
            },
          ),
        );
      }
    }
    if (kind == ActivityKind.discussions ||
        kind == ActivityKind.notifications ||
        kind == ActivityKind.saved) {
      final threads = _items(
        (await dio.get<dynamic>(
          'messages/threads',
          queryParameters: params,
        )).data,
      );
      if (kind == ActivityKind.notifications && threads.isNotEmpty) {
        final result = await dio.post<dynamic>(
          'messages/unread-per-thread',
          data: {
            ...params,
            'threads': [
              for (final thread in threads)
                {'threadId': thread['threadId'], 'since': 0},
            ],
          },
        );
        final raw = result.data;
        final counts = raw is Map ? raw['counts'] : null;
        if (counts is Map) {
          for (final thread in threads) {
            thread['unreadCount'] = counts[thread['threadId']] ?? 0;
          }
        }
      }
      if (kind == ActivityKind.saved) {
        // The web stores favourites on each message, rather than in a separate list endpoint.
        for (final thread in threads) {
          final threadId = thread['threadId']?.toString();
          if (threadId == null) continue;
          String? cursor;
          final seen = <String>{};
          do {
            final response = await dio.get<dynamic>(
              'messages',
              queryParameters: {
                ...params,
                'threadId': threadId,
                'take': 100,
                'direction': 'backward',
                'cursor': ?cursor,
              },
            );
            items.addAll(
              _items(response.data)
                  .where((e) => e['favorited'] == true)
                  .map((e) => {...e, 'threadId': threadId}),
            );
            final raw = response.data;
            cursor = raw is Map ? raw['nextCursor']?.toString() : null;
            if (cursor != null && !seen.add(cursor)) {
              throw const FormatException(
                'Не удалось загрузить продолжение сообщений.',
              );
            }
          } while (cursor != null && cursor.isNotEmpty);
        }
      } else {
        items.addAll(
          threads.where(
            (e) =>
                kind == ActivityKind.discussions ||
                (e['threadId']?.toString().startsWith('dm:') == true &&
                    (e['unreadCount'] as num? ?? 0) > 0),
          ),
        );
      }
    }
    final entries = items.map(ActivityEntry.fromJson).toList();
    entries.sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );
    return entries;
  }
}
