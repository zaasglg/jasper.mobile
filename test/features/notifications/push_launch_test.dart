import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/features/notifications/data/push_notification.dart';
import 'package:jospar/features/notifications/domain/push_gateway.dart';
import 'package:jospar/features/notifications/presentation/push_cubit.dart';
import 'package:jospar/features/notifications/presentation/push_launch_service.dart';

class _Gateway implements PushGateway {
  @override
  bool get supported => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Push extends PushCubit {
  _Push() : super(_Gateway());
  @override
  Future<void> initialize({
    required void Function(PushNotificationData) onOpened,
    void Function()? onMessage,
  }) async {
    onOpened(
      const PushNotificationData(
        data: {'messageId': 'push', 'threadId': 'thread'},
      ),
    );
  }
}

void main() {
  testWidgets('cold-start push waits for splash navigation then opens chat', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    authSession.markAuthenticated();
    final storage = AuthTokenStorage(const FlutterSecureStorage());
    await storage.save('session');
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => const Scaffold(body: Text('Splash')),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Dashboard')),
        ),
        GoRoute(
          path: '/messenger/:id',
          builder: (_, _) => const Scaffold(body: Text('Chat')),
        ),
      ],
    );
    final cubit = _Push();
    final service = PushLaunchService(router, storage, cubit);
    addTearDown(() async {
      service.dispose();
      await cubit.close();
      router.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await service.initialize();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/splash');
    router.go('/dashboard');
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/messenger/thread',
    );
    expect(find.text('Chat'), findsOneWidget);
  });
}
