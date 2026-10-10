import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/voice/assistant_launch_service.dart';

void main() {
  testWidgets(
    'cold Siri launch waits for splash/login and then opens the assistant once',
    (tester) async {
      const channel = MethodChannel('test/assistant_launch');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          for (final path in ['/splash', '/login', '/dashboard', '/assistant'])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text(path)),
            ),
        ],
      );
      final launch = AssistantLaunchService(router, channel: channel);
      addTearDown(router.dispose);
      addTearDown(launch.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await launch.initialize();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/splash');
      router.go('/login');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(
        (router.routerDelegate.currentConfiguration.last
                as ImperativeRouteMatch)
            .matches
            .uri
            .toString(),
        '/assistant?voice=true',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    },
  );
  testWidgets(
    'repeated Siri invocation activates the current assistant without duplicate pages',
    (tester) async {
      const channel = MethodChannel('test/repeated_launch');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final router = GoRouter(
        initialLocation: '/assistant',
        routes: [
          GoRoute(path: '/assistant', builder: (_, _) => const Scaffold()),
        ],
      );
      final launch = AssistantLaunchService(router, channel: channel);
      addTearDown(router.dispose);
      addTearDown(launch.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await launch.initialize();
      var calls = 0;
      final subscription = launch.repeatedLaunches.listen((_) => calls++);
      addTearDown(subscription.cancel);
      launch.requestLaunch();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(router.canPop(), isFalse);
    },
  );
}
