import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/widgets/user_avatar.dart';
import 'package:jospar/features/activity/data/activity_repository.dart';
import 'package:jospar/features/activity/presentation/mention_activity_tile.dart';
import 'package:jospar/features/chat/presentation/widgets/reaction_emoji.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'activity cards display quotes and reactions in ${dark ? 'dark' : 'light'} theme',
      (t) async {
        t.view.physicalSize = const Size(320, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var opened = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    MentionActivityTile(
                      entry: const ActivityEntry(
                        id: 'mention:1',
                        title: 'Автор · Канал',
                        text:
                            '↩ @Коллега: «Исходный текст»\n\nОтвет на сообщение',
                        threadId: 'channel',
                      ),
                      onTap: () => opened++,
                    ),
                    MentionActivityTile(
                      entry: ActivityEntry(
                        id: 'reaction:2',
                        title: '👍 · Автор с очень длинным именем · Канал',
                        text: 'Текст сообщения',
                        threadId: 'channel',
                        createdAt: DateTime(2026, 11, 24, 9),
                      ),
                      onTap: () => opened++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(UserAvatar), findsNWidgets(2));
        expect(find.byType(ReactionEmoji), findsOneWidget);
        expect(find.text('Вас упомянули'), findsOneWidget);
        expect(find.text('Реакция на ваше сообщение'), findsOneWidget);
        expect(find.text('Коллега: Исходный текст'), findsOneWidget);
        expect(find.text('Ответ на сообщение'), findsOneWidget);
        await t.tap(find.text('Ответ на сообщение'));
        expect(opened, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
  test('activity parses author avatar metadata', () {
    final item = ActivityEntry.fromJson(const {
      'id': 'mention:1',
      'user': {'id': 'person', 'name': 'Автор', 'avatarUrl': '/photo.jpg'},
      'message': {'text': 'Привет', 'threadId': 'channel'},
    });
    expect(item.authorId, 'person');
    expect(item.avatarUrl, '/photo.jpg');
    expect(item.copyWith(text: 'Ответ').avatarUrl, '/photo.jpg');
    expect(item.toJson()['authorId'], 'person');
  });
}
