import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jospar/features/dashboard/data/mentions_read_storage.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_mentions_widget.dart';

void main() {
  testWidgets(
    'mention source filter and mark-all affect only the selected source',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var saved = <String>{};
      Widget app(Key key) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardMentionsWidget(
              key: key,
              loadRead: () async => saved,
              saveRead: (ids) async {
                saved = {...ids};
              },
              onOpenTask: (_) async {},
              entries: const [
                {
                  'id': 'same',
                  'feedKind': 'mention',
                  'source': 'messenger',
                  'text': 'Обсуждение в чате',
                  'createdAt': '2026-10-31',
                  'user': {'name': 'Данияр'},
                },
                {
                  'id': 'project',
                  'feedKind': 'mention',
                  'source': 'task',
                  'taskId': 'task42',
                  'text': '<p>Согласовать @[RBV]</p>',
                  'createdAt': '2026-10-30',
                  'user': {'name': 'Алия'},
                },
                {
                  'id': 'same',
                  'feedKind': 'reaction',
                  'emoji': '👍',
                  'message': {'text': 'Готово'},
                  'createdAt': '2026-10-29',
                  'user': {'name': 'Алия'},
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(const ValueKey('first')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Согласовать @RBV', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('<p>', findRichText: true), findsNothing);
      await tester.tap(find.byTooltip('Источник упоминаний'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-option-task')));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(find.text('Обсуждение в чате'), findsNothing);
      expect(
        find.textContaining('Согласовать @RBV', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Прочитать всё в выбранных фильтрах'));
      await tester.pumpAndSettle();
      expect(saved, {'mention:project'});
      expect(find.text('Нет упоминаний'), findsOneWidget);
      await tester.tap(find.byTooltip('Источник упоминаний'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('dashboard-option-messenger')),
      );
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(find.text('Обсуждение в чате'), findsOneWidget);
      expect(
        find.textContaining('отреагировал', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Прочитать всё в выбранных фильтрах'));
      await tester.pumpAndSettle();
      expect(saved, {'mention:project', 'mention:same', 'reaction:same'});
      await tester.pumpWidget(app(const ValueKey('restored')));
      await tester.pumpAndSettle();
      expect(find.text('Нет упоминаний'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('opening a project mention marks it read and opens its task', (
    tester,
  ) async {
    String? opened;
    Set<String>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardMentionsWidget(
            entries: const [
              {
                'id': '1',
                'source': 'task',
                'taskId': 'task42',
                'text': 'Проверить смету',
              },
            ],
            saveRead: (ids) async {
              saved = ids;
            },
            onOpenTask: (id) async {
              opened = id;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Проверить смету'));
    await tester.pumpAndSettle();
    expect(opened, 'task42');
    expect(saved, {'mention:1'});
    expect(find.text('Нет упоминаний'), findsOneWidget);
  });
  test('read state is isolated between users and workspaces', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = MentionsReadStorage(FlutterSecureStorage());
    await storage.save('u', 'w', {'mention:1'});
    expect(await storage.load('u', 'w'), {'mention:1'});
    expect(await storage.load('other', 'w'), isEmpty);
    expect(await storage.load('u', 'other'), isEmpty);
  });
}
