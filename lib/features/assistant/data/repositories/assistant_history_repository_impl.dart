import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../domain/entities/assistant_conversation.dart';
import '../../domain/repositories/assistant_history_repository.dart';
import '../models/assistant_message_dto.dart';

class AssistantHistoryRepositoryImpl implements AssistantHistoryRepository {
  AssistantHistoryRepositoryImpl(this._tokens, this._storage);
  final AuthTokenStorage _tokens;
  final FlutterSecureStorage _storage;
  Future<void> _writes = Future.value();
  @override
  Future<String?> scope(String workspaceId) async {
    final token = await _tokens.read();
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final owner = claims is Map ? claims['sub'] ?? claims['id'] : null;
    if (owner is! String || owner.isEmpty) return null;
    return 'assistant_history.v1.${Uri.encodeComponent(owner)}.${Uri.encodeComponent(workspaceId)}';
  }

  @override
  Future<List<AssistantConversation>> load(String scope) async {
    await _writes;
    final raw = await _storage.read(key: scope);
    if (raw == null) return [];
    final rows = jsonDecode(raw);
    if (rows is! List) throw const FormatException('Invalid assistant history');
    return rows
        .whereType<Map>()
        .map(
          (row) => AssistantConversation(
            id: row['id'] as String,
            updatedAt: DateTime.parse(row['updatedAt'] as String),
            draft: row['draft'] as String? ?? '',
            projectId: row['projectId'] as String?,
            projectName: row['projectName'] as String?,
            stopped: row['stopped'] == true,
            messages: (row['messages'] as List? ?? [])
                .whereType<Map>()
                .map(
                  (m) => AssistantMessageDto.fromJson(
                    Map<String, dynamic>.from(m),
                  ).toEntity(),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Future<void> save(String scope, List<AssistantConversation> conversations) {
    // Keep metadata/results, but never retain uploaded media bytes in history.
    dynamic metadata(dynamic value) {
      if (value is List) return value.map(metadata).toList();
      if (value is Map) {
        return <String, dynamic>{
          for (final entry in value.entries)
            if (entry.key != 'dataUrl' && entry.key != 'images')
              entry.key.toString(): metadata(entry.value),
        };
      }
      if (value is String && value.startsWith('data:')) return '';
      return value;
    }

    final raw = jsonEncode(
      conversations
          .map(
            (c) => {
              'id': c.id,
              'updatedAt': c.updatedAt.toIso8601String(),
              'draft': c.draft,
              'projectId': c.projectId,
              'projectName': c.projectName,
              'stopped': c.stopped,
              'messages': c.messages
                  .map(
                    (m) => metadata({
                      ...AssistantMessageDto.fromEntity(m).toJson(),
                      if (m.content.isEmpty && m.images.isNotEmpty)
                        'content': 'Изображение (содержимое не сохранено)',
                    }),
                  )
                  .toList(),
            },
          )
          .toList(),
    );
    if (utf8.encode(raw).length > 2 * 1024 * 1024) {
      return Future.error(const FormatException('Assistant history is full'));
    }
    final write = _writes.then((_) => _storage.write(key: scope, value: raw));
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
