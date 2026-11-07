import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:jospar/features/chat/presentation/cubit/conversation_cubit.dart';

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'selected_workspace_id': 'w',
    }),
  );
  test(
    'message favourites, edits and deletes use server contracts and retain state on failure',
    () async {
      final adapter = _ActionsAdapter();
      final repo = ChatRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      final cubit = ConversationCubit(
        repo,
        const ChatConversationModel(
          id: 'c',
          threadId: 'c',
          title: 'Канал',
          isChannel: true,
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(adapter.requests.last.path, 'messages/threads/read');
      expect(adapter.requests.last.data, {'workspaceId': 'w', 'threadId': 'c'});
      expect(await cubit.messageAction('m', 'favorite'), true);
      expect(cubit.state.messages.single.favorited, true);
      expect(adapter.requests.last.path, 'messages/m/favorite');
      adapter.fail = true;
      expect(await cubit.messageAction('m', 'edit', text: 'Новое'), false);
      expect(cubit.state.messages.single.text, 'Сообщение');
      expect(cubit.state.messages.single.favorited, true);
      expect(cubit.state.isSending, false);
      adapter.fail = false;
      expect(await cubit.messageAction('m', 'edit', text: ' Новое '), true);
      expect(adapter.requests.last.data, {'text': 'Новое'});
      expect(cubit.state.messages.single.text, 'Новое');
      expect(await cubit.messageAction('m', 'delete'), true);
      expect(cubit.state.messages, isEmpty);
    },
  );
  test(
    'channel member envelope is parsed before a membership update',
    () async {
      final adapter = _ActionsAdapter();
      final repo = ChatRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      final members = await repo.channelMembers('c');
      expect(members.single.userId, 'u');
      await repo.setChannelMembers('c', members.map((e) => e.userId).toList());
      expect(adapter.requests.last.method, 'PUT');
      expect(adapter.requests.last.data, {
        'memberIds': ['u'],
      });
    },
  );
}

class _ActionsAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool fail = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    Object result = {};
    if (options.path == 'messages' && options.method == 'GET') {
      result = [
        {
          'id': 'm',
          'threadId': 'c',
          'text': 'Сообщение',
          'userId': 'u',
          'createdAt': '2026-10-30T10:00:00Z',
        },
      ];
    }
    if (options.path == 'channels/c/members' && options.method == 'GET') {
      result = {
        'canManage': true,
        'members': [
          {'id': 'u', 'name': 'Участник'},
        ],
      };
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      fail ? 403 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
