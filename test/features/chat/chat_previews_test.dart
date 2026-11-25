import 'package:jospar/core/localization/app_translations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/data/models/chat_message_preview_model.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:jospar/features/chat/presentation/messenger_list_strings.dart';

class _Workspace extends WorkspaceSelectionStorage {
  const _Workspace() : super(const FlutterSecureStorage());
  @override
  Future<String?> read() async => 'workspace';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppTranslations.load);
  test(
    'thread summaries match channels, subchannels and DMs by thread ID, not last author',
    () async {
      final dio = Dio();
      final repo = ChatRepositoryImpl(dio, const _Workspace());
      addTearDown(repo.dispose);
      addTearDown(dio.close);
      final requests = <RequestOptions>[];
      var heads = <Map<String, dynamic>>[
        {
          'threadId': 'parent',
          'text': 'Обновление канала',
          'user': {'id': 'peer', 'name': 'Анна'},
        },
        {
          'threadId': 'child',
          'text': 'Вложенная тема',
          'user': {'id': 'me', 'name': 'Автор'},
        },
        {
          'threadId': 'dm:me:peer',
          'text': 'Личное сообщение',
          'user': {'id': 'me', 'name': 'Автор'},
        },
      ];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            requests.add(r);
            final data = <String, dynamic>{
              'channels': [
                {'id': 'parent', 'name': 'Канал'},
                {'id': 'child', 'parentId': 'parent', 'name': 'Подканал'},
              ],
              'users/me': {'id': 'me'},
              'users/messenger-candidates': [
                {'id': 'peer', 'name': 'Анна'},
              ],
              'messages/threads': heads,
              'messages/unread-per-thread': {'counts': {}},
            };
            h.resolve(Response(requestOptions: r, data: data[r.path]));
          },
        ),
      );
      var conversations = await repo.getConversations();
      final channel = conversations.firstWhere((c) => c.id == 'parent');
      expect(channel.lastMessage!.text, 'Обновление канала');
      expect(channel.lastMessage!.authorName, 'Анна');
      expect(
        conversations.firstWhere((c) => c.id == 'child').lastMessage!.text,
        'Вложенная тема',
      );
      final dm = conversations.firstWhere((c) => c.id == 'peer');
      expect(dm.threadId, 'dm:me:peer');
      expect(dm.lastMessage!.text, 'Личное сообщение');
      expect(dm.lastMessage!.isOwn, isTrue);
      expect(ChatConversationModel.fromJson(dm.toJson()), dm);
      expect(
        dm.copyWith(imageUrl: null, unreadCount: 4).lastMessage,
        dm.lastMessage,
      );
      expect(dm.copyWith(lastMessage: null).lastMessage, isNull);
      expect(requests.where((r) => r.path == 'messages'), isEmpty);
      expect(requests.length, 5);
      heads = [heads.first];
      conversations = await repo.getConversations();
      final noDm = conversations.firstWhere((c) => c.id == 'peer');
      expect(noDm.lastMessage, isNull);
      expect(noDm.hasThread, isFalse);
      expect(
        conversations.firstWhere((c) => c.id == 'child').lastMessage,
        isNull,
      );
    },
  );
  test(
    'previews flatten quotes and whitespace, round trip, and label media in ru/kk',
    () {
      const ru = MessengerListStrings(false), kk = MessengerListStrings(true);
      final preview = ChatMessagePreviewModel.fromThreadJson(const {
        'text': '↩ @Анна: «Исходное сообщение»\n\nНовый\n ответ',
        'user': {'id': 'me', 'name': 'Автор'},
      }, currentUserId: 'me');
      expect(preview.text, 'Новый ответ');
      expect(ChatMessagePreviewModel.fromJson(preview.toJson()), preview);
      expect(ru.preview(preview, isChannel: false), 'Вы: Новый ответ');
      expect(kk.preview(preview, isChannel: false), 'Сіз: Новый ответ');
      final channel = preview.copyWith(isOwn: false, authorName: 'Анна');
      expect(ru.preview(channel, isChannel: true), 'Анна: Новый ответ');
      expect(ru.preview(channel, isChannel: false), 'Новый ответ');
      final call = ChatMessagePreviewModel.fromThreadJson(const {
        'text': '{"callId":"call","mode":"video"}',
      });
      expect(ru.preview(call, isChannel: true), 'Звонок');
      expect(kk.preview(call, isChannel: true), 'Қоңырау');
      expect(
        ru.preview(
          preview.copyWith(kind: ChatMessageKind.audio),
          isChannel: false,
        ),
        'Вы: Голосовое сообщение',
      );
      expect(
        ru.preview(const ChatMessagePreviewModel(text: ''), isChannel: false),
        'Сообщение',
      );
      expect(
        ru.preview(
          const ChatMessagePreviewModel(text: 'data:image/png;base64,AAAA'),
          isChannel: false,
        ),
        'Сообщение',
      );
    },
  );
}
