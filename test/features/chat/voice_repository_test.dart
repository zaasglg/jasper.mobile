import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:jospar/features/chat/presentation/cubit/conversation_cubit.dart';

class _Workspace extends WorkspaceSelectionStorage {
  const _Workspace() : super(const FlutterSecureStorage());
  @override
  Future<String?> read() async => 'workspace';
}

class _Adapter implements HttpClientAdapter {
  bool fail = false;
  Map<String, dynamic>? sent;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == 'users/me') {
      return ResponseBody.fromString(
        '{"id":"sender"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    sent = Map<String, dynamic>.from(options.data as Map);
    expect(
      sent!.keys.toSet().difference({
        'threadId',
        'workspaceId',
        'userId',
        'kind',
        'text',
        'duration',
        'transcript',
        'taskRef',
        'mention',
      }),
      isEmpty,
      reason: 'Server rejects properties outside CreateMessageDto',
    );
    expect(sent!['userId'], isA<String>());
    return ResponseBody.fromString(
      jsonEncode(
        fail
            ? {'message': 'Upload failed'}
            : {
                ...sent!,
                'id': 'voice',
                'authorId': 'sender',
                'createdAt': '2026-10-05T12:00:00Z',
              },
      ),
      fail ? 500 : 201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const channel = ChatConversationModel(
    id: 'channel',
    threadId: 'thread',
    title: 'general',
    isChannel: true,
  );
  for (final isChannel in [true, false]) {
    test(
      'file and video uploads use mention and only allowed API fields',
      () async {
        final adapter = _Adapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://jospar.me/api/'))
          ..httpClientAdapter = adapter;
        final cubit = ConversationCubit(
          ChatRepositoryImpl(dio, const _Workspace()),
          channel,
        );
        addTearDown(() async {
          await cubit.close();
          dio.close();
        });
        expect(
          await cubit.sendAttachment(
            text: '📎 doc.pdf · 1 КБ',
            dataUrl: 'data:application/pdf;base64,AQID',
          ),
          isTrue,
        );
        expect(adapter.sent, containsPair('kind', 'TEXT'));
        expect(
          adapter.sent,
          containsPair('mention', 'data:application/pdf;base64,AQID'),
        );
        expect(cubit.state.messages.single.isFile, isTrue);
        expect(
          await cubit.sendAttachment(
            text: '📹 видео 3с',
            dataUrl: 'data:video/mp4;base64,AQID',
            duration: 3,
          ),
          isTrue,
        );
        expect(adapter.sent, containsPair('duration', 3));
        expect(cubit.state.messages.last.kind, ChatMessageKind.videoMessage);
      },
    );
    test(
      'text send uses valid API fields for ${isChannel ? "channel" : "direct chat"}',
      () async {
        final adapter = _Adapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://jospar.me/api/'))
          ..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final repository = ChatRepositoryImpl(dio, const _Workspace());
        final message = await repository.sendMessage(
          conversation: ChatConversationModel(
            id: 'target',
            threadId: 'thread',
            title: 'chat',
            isChannel: isChannel,
          ),
          text: 'regret',
        );
        expect(adapter.sent, containsPair('userId', 'sender'));
        expect(adapter.sent, containsPair('threadId', 'thread'));
        expect(adapter.sent, containsPair('text', 'regret'));
        expect(adapter.sent!.containsKey('channelId'), isFalse);
        expect(adapter.sent!.containsKey('recipientId'), isFalse);
        expect(message.kind, ChatMessageKind.text);
      },
    );
  }
  test(
    'voice send matches web AUDIO transcript contract and is added after success',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://jospar.me/api/'))
        ..httpClientAdapter = adapter;
      final cubit = ConversationCubit(
        ChatRepositoryImpl(dio, const _Workspace()),
        channel,
      );
      addTearDown(() async {
        await cubit.close();
        dio.close();
      });
      expect(await cubit.sendVoice('data:audio/mp4;base64,AQID', 3), isTrue);
      expect(adapter.sent, containsPair('kind', 'AUDIO'));
      expect(
        adapter.sent,
        containsPair('transcript', 'data:audio/mp4;base64,AQID'),
      );
      expect(adapter.sent, containsPair('duration', 3));
      expect(adapter.sent, containsPair('userId', 'sender'));
      expect(adapter.sent, containsPair('threadId', 'thread'));
      expect(cubit.state.messages.single.kind, ChatMessageKind.audio);
      adapter.fail = true;
      expect(await cubit.sendVoice('data:audio/mp4;base64,AQID', 4), isFalse);
      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.isSending, isFalse);
      expect(cubit.state.error, isNotNull);
    },
  );
}
