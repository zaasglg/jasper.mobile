import 'package:jospar/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/activity/data/activity_repository.dart';
import 'package:jospar/features/activity/presentation/activity_screen.dart';

class _Repository implements ActivityRepository {
  _Repository(this.items);
  final List<ActivityEntry> items;
  @override
  Future<List<ActivityEntry>> load(ActivityKind kind) async => items;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() => sl.reset());

  for (final dark in [false, true]) {
    testWidgets('notifications remain readable and open tasks, dark: $dark', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      sl.registerSingleton<ActivityRepository>(
        _Repository([
          ActivityEntry(
            id: 'reaction:1',
            title: '👍 · Удалённый пользователь',
            text: 'Текст сообщения с реакцией',
            taskId: 'task',
            createdAt: DateTime(2025, 1, 2),
          ),
          ActivityEntry.fromJson({
            'id': 'call-event',
            'user': {'name': 'Автор звонка'},
            'threadId': 'dm:a:b',
            'kind': 'CALL',
            'text':
                '{"callId":"call","mode":"audio","status":"ended","createdById":"author"}',
          }),
          const ActivityEntry(
            id: 'mention:2',
            title: 'Автор с длинным именем',
            text: 'Вас ждут в обсуждении',
          ),
        ]),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const ActivityScreen(kind: ActivityKind.notifications),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (_, _) => const Scaffold(body: Text('Task opened')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: dark ? AppTheme.dark : AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Реакция на сообщение'), findsOneWidget);
      expect(find.text('Звонок завершён'), findsOneWidget);
      expect(find.textContaining('callId'), findsNothing);
      expect(find.textContaining('createdById'), findsNothing);
      expect(find.text('Упомянули вас'), findsOneWidget);
      expect(find.text('Удалённый пользователь'), findsOneWidget);
      expect(find.text('👍 · Удалённый пользователь'), findsNothing);
      expect(find.text('02.01.2025'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppPalette(dark).canvas,
      );
      expect(
        tester.widget<Text>(find.text('Последние события')).style!.color,
        AppPalette(dark).muted,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Текст сообщения с реакцией'));
      await tester.pumpAndSettle();
      expect(find.text('Task opened'), findsOneWidget);
    });
  }
  testWidgets('notifications show an empty state without fabricated events', (
    tester,
  ) async {
    sl.registerSingleton<ActivityRepository>(_Repository([]));
    await tester.pumpWidget(
      const MaterialApp(home: ActivityScreen(kind: ActivityKind.notifications)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Новых уведомлений пока нет'), findsOneWidget);
    expect(find.text('Последние события'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
