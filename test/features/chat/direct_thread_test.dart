import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';

class _Workspace extends WorkspaceSelectionStorage {
  const _Workspace() : super(const FlutterSecureStorage());

  @override
  Future<String?> read() async => 'workspace';
}

void main() {
  test('direct thread participants use the same sorted order as the web', () {
    for (final ids in [
      ['z', 'a'],
      ['a', 'z'],
    ]) {
      final chat = ChatConversationModel.fromUserJson({
        'id': ids[1],
        'name': 'Peer',
      }, currentUserId: ids[0]);
      expect(chat.threadId, 'dm:a:z');
    }
  });

  test('delete hides a DM server-side while clear keeps it visible', () async {
    final dio = Dio();
    final repository = ChatRepositoryImpl(dio, const _Workspace());
    addTearDown(repository.dispose);
    addTearDown(dio.close);
    final writes = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          writes.add(r);
          h.resolve(Response(requestOptions: r, data: {'success': true}));
        },
      ),
    );
    await repository.clearConversation('dm:a:b');
    await repository.deleteConversation('dm:a:b');
    expect(writes.map((r) => r.path), everyElement('messages/threads/clear'));
    expect(writes.last.method, 'POST');
    expect(writes.first.data, {
      'threadId': 'dm:a:b',
      'workspaceId': 'workspace',
      'keepVisible': true,
    });
    expect(writes.last.data, {
      'threadId': 'dm:a:b',
      'workspaceId': 'workspace',
      'keepVisible': false,
    });
    await expectLater(
      repository.deleteConversation('channel'),
      throwsA(isA<Exception>()),
    );
    expect(writes.length, 2);
  });

  for (final existing in [false, true]) {
    test(
      'loads ${existing ? "existing" : "new"} direct chat with a valid thread',
      () async {
        final dio = Dio();
        addTearDown(dio.close);
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final data = <String, dynamic>{
                'channels': <dynamic>[],
                'users/me': {'id': 'z'},
                'users/messenger-candidates': [
                  {'id': 'z', 'name': 'Me'},
                  {'id': 'a', 'name': 'Peer'},
                ],
                'messages/threads': existing
                    ? [
                        {'threadId': 'dm:a:z', 'unreadCount': 3},
                      ]
                    : <dynamic>[],
                'messages': <dynamic>[],
              };
              if (options.path == 'messages') {
                expect(options.queryParameters['threadId'], 'dm:a:z');
                expect(options.queryParameters['workspaceId'], 'workspace');
              }
              handler.resolve(
                Response(requestOptions: options, data: data[options.path]),
              );
            },
          ),
        );
        final repository = ChatRepositoryImpl(dio, const _Workspace());
        final chat = (await repository.getConversations()).single;
        expect(chat.id, 'a');
        expect(chat.threadId, 'dm:a:z');
        expect(chat.unreadCount, existing ? 3 : 0);
        expect(await repository.getMessages(chat.threadId), isEmpty);
      },
    );
  }
}
