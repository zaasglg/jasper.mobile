import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/activity/data/activity_repository.dart';
import 'package:jospar/features/activity/presentation/activity_screen.dart';

class _ActivityRepository implements ActivityRepository {
  @override
  Future<List<ActivityEntry>> load(ActivityKind kind) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    sl.registerSingleton<ActivityRepository>(_ActivityRepository());
  });
  tearDown(() => sl.reset());

  testWidgets('mentions back returns to messenger inside a shell navigator', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/messenger',
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/messenger',
              builder: (_, _) => const Scaffold(body: Text('Messenger')),
            ),
          ],
        ),
        GoRoute(
          path: '/activity/mentions',
          builder: (_, _) => const ActivityScreen(kind: ActivityKind.mentions),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/activity/mentions');
    await tester.pumpAndSettle();
    expect(find.text('Упоминания и реакции'), findsOneWidget);
    final back = tester.widget<BackButton>(find.byType(BackButton)).onPressed!;
    back();
    back();
    await tester.pumpAndSettle();
    expect(find.text('Messenger'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/messenger');
    expect(tester.takeException(), isNull);
  });

  for (final directEntry in [false, true]) {
    testWidgets(
      directEntry
          ? 'back from a direct activity link opens messenger'
          : 'rapid back taps only pop the activity route once',
      (tester) async {
        final router = GoRouter(
          initialLocation: directEntry ? '/activity/saved' : '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/messenger',
              builder: (_, _) => const Scaffold(body: Text('Messenger')),
            ),
            GoRoute(
              path: '/activity/saved',
              builder: (_, _) => const ActivityScreen(kind: ActivityKind.saved),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        if (!directEntry) {
          router.push('/messenger');
          await tester.pumpAndSettle();
          router.push('/activity/saved');
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byType(BackButton));
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Messenger'), findsOneWidget);
        expect(router.canPop(), !directEntry);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
