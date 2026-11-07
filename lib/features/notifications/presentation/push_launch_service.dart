import '../data/mobile_push_registration.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/storage/auth_token_storage.dart';
import '../../chat/data/chat_list_changes.dart';
import '../data/push_notification.dart';
import 'push_cubit.dart';

class PushLaunchService {
  PushLaunchService(this.router, this.storage, this.cubit, {this.registration});
  final MobilePushRegistration? registration;
  final GoRouter router;
  final AuthTokenStorage storage;
  final PushCubit cubit;
  PushNotificationData? _pending;
  final _seen = <String>{};
  bool _opening = false;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    router.routerDelegate.removeListener(_routeChanged);
    authSession.removeListener(_authChanged);
    _pending = null;
  }

  Future<void> initialize() async {
    registration?.start();
    router.routerDelegate.addListener(_routeChanged);
    authSession.addListener(_authChanged);
    await cubit.initialize(
      onOpened: (message) {
        if (message.id.isNotEmpty && !_seen.add(message.id)) return;
        if (_seen.length > 100) _seen.remove(_seen.first);
        _pending = message;
        unawaited(_tryOpen());
      },
      onMessage: notifyChatListChanges,
    );
  }

  void _routeChanged() {
    unawaited(registration?.synchronize() ?? Future<void>.value());
    unawaited(_tryOpen());
  }

  void _authChanged() {
    if (authSession.requiresLogin) {
      _pending = null;
      unawaited(cubit.revokeToken());
    } else {
      unawaited(cubit.refresh());
    }
  }

  Future<void> _tryOpen() async {
    if (_disposed ||
        _pending == null ||
        _opening ||
        authSession.requiresLogin) {
      return;
    }
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path == '/' || path == '/splash' || path == '/login') return;
    _opening = true;
    try {
      if ((await storage.read())?.isNotEmpty != true ||
          authSession.requiresLogin) {
        return;
      }
      final pending = _pending;
      final recipient = pending?.data['recipientId'];
      if (recipient != null &&
          recipient != pushAccountId(await storage.read() ?? '')) {
        _pending = null;
        return;
      }
      final currentPath = router.routerDelegate.currentConfiguration.uri.path;
      if (_disposed ||
          currentPath == '/' ||
          currentPath == '/splash' ||
          currentPath == '/login') {
        return;
      }
      if (pending != null) {
        _pending = null;
        router.push(pending.route);
      }
    } finally {
      _opening = false;
    }
  }
}
