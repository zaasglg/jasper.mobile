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
