import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:jospar/features/chat/domain/repositories/chat_repository.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/presentation/cubit/conversation_cubit.dart';

class _Workspace extends WorkspaceSelectionStorage {
  const _Workspace() : super(const FlutterSecureStorage());
  @override
  Future<String?> read() async => 'workspace';
}

Map<String, dynamic> _raw(int number, {String? text}) => {
  'id': '$number'.padLeft(4, '0'),
  'text': text ?? 'Message $number',
  'createdAt': DateTime.utc(
    2026,
  ).add(Duration(seconds: number)).toIso8601String(),
};

void main() {
  test(
    'periodic full reconciliation picks up changes outside recent window',
    () async {
      final repository = _RefreshRepository();
      final cubit = ConversationCubit(
        repository,
        const ChatConversationModel(
          id: 'thread',
          threadId: 'thread',
          title: 'Chat',
          isChannel: true,
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      for (var i = 0; i < 6; i++) {
        await cubit.load(silent: true);
      }
      expect(repository.windows, 5);
      expect(repository.fullLoads, 2);
      expect(cubit.state.messages.single.text, 'Full 2');
    },
  );
  test(
    'poll refreshes bounded tail, retains older history and removes deleted tail rows',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    'data': [
                      for (var i = 102; i <= 201; i++)
                        if (i != 150) _raw(i, text: i == 190 ? 'Edited' : null),
                    ],
                    'nextCursor': '0102',
                  },
                ),
              );
            },
          ),
        );
      addTearDown(dio.close);
      final repository = ChatRepositoryImpl(dio, const _Workspace());
      final previous = [
        for (var i = 1; i <= 200; i++) ChatMessageModel.fromJson(_raw(i)),
      ];
      final result = await repository.refreshMessages('thread', previous);
      expect(requests.length, 1);
      expect(requests.single.queryParameters, containsPair('take', 100));
      expect(
        requests.single.queryParameters,
        containsPair('direction', 'backward'),
      );
      expect(result.first.id, '0001');
      expect(result.last.id, '0201');
      expect(result.any((message) => message.id == '0150'), isFalse);
      expect(
        result.firstWhere((message) => message.id == '0190').text,
        'Edited',
      );
    },
  );

  test('large backlog is fetched until a known message is reached', () async {
    final cursors = <Object?>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            final cursor = request.queryParameters['cursor'];
            cursors.add(cursor);
            final start = cursor == null
                ? 351
                : cursor == '0351'
                ? 251
                : 151;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'data': [for (var i = start; i < start + 100; i++) _raw(i)],
                  'nextCursor': '$start'.padLeft(4, '0'),
                },
              ),
            );
          },
        ),
      );
    addTearDown(dio.close);
    final repository = ChatRepositoryImpl(dio, const _Workspace());
    final result = await repository.refreshMessages('thread', [
      for (var i = 1; i <= 200; i++) ChatMessageModel.fromJson(_raw(i)),
    ]);
    expect(cursors, [null, '0351', '0251']);
    expect(result.length, 450);
    expect(result.last.id, '0450');
  });
}

class _RefreshRepository implements ChatRepository, ChatRefreshRepository {
  int fullLoads = 0, windows = 0;
  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) async {
    fullLoads++;
    return [ChatMessageModel.fromJson(_raw(1, text: 'Full $fullLoads'))];
  }

  @override
  Future<List<ChatMessageModel>> refreshMessages(
    String threadId,
    List<ChatMessageModel> previous,
  ) async {
    windows++;
    return previous;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
