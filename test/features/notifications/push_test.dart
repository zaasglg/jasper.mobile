import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/features/notifications/data/mobile_push_registration.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/notifications/data/native_push_gateway.dart';
import 'package:jospar/features/notifications/data/push_notification.dart';
import 'package:jospar/features/notifications/domain/push_gateway.dart';
import 'package:jospar/features/notifications/presentation/push_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'mobile registration binds account and sends platform ${platform.name}',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        FlutterSecureStorage.setMockInitialValues({});
        authSession.markAuthenticated();
        final storage = AuthTokenStorage(const FlutterSecureStorage());
        final jwt =
            'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'account'})))}.signature';
        await storage.save(jwt);
        final gateway = _Gateway();
        final cubit = PushCubit(gateway);
        await cubit.initialize(onOpened: (_) {});
        final requests = <RequestOptions>[];
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                requests.add(request);
                handler.resolve(
                  Response(
                    requestOptions: request,
                    data: {'registered': true},
                    statusCode: 200,
                  ),
                );
              },
            ),
          );
        final registration = MobilePushRegistration(dio, storage, cubit);
        await registration.synchronize();
        await registration.synchronize();
        expect(gateway.account, 'account');
        expect(requests.single.path, 'push/mobile/devices');
        expect(requests.single.data, {
          'token': 'token',
          'platform': platform == TargetPlatform.iOS ? 'ios' : 'android',
        });
        expect(cubit.state.registered, isTrue);
        await storage.clear();
        authSession.markUnauthenticated();
        await registration.synchronize();
        expect(requests.length, 1);
        await registration.dispose();
        await cubit.close();
        await gateway.controller.close();
        authSession.markAuthenticated();
      },
    );
  }
  test(
    'notification targets only internal routes and preserves thread IDs',
    () {
      final task = PushNotificationData.fromJson({
        'taskId': 'task/one',
        'url': 'https://evil.test',
      });
      expect(task.route, '/tasks/task%2Fone');
      final chat = PushNotificationData.fromJson({
        'threadId': 'dm:one:two',
        'chatMessageId': 'a&b',
      });
      final uri = Uri.parse(chat.route);
      expect(uri.pathSegments, ['messenger', 'dm:one:two']);
      expect(uri.queryParameters['messageId'], 'a&b');
      expect(
        PushNotificationData.fromJson({'url': 'https://evil.test'}).route,
        '/activity/notifications',
      );
      expect(PushNotificationData.fromJson(chat.toJson()).copyWith(), chat);
    },
  );
  test(
    'initial notification, live opens and foreground messages are delivered once per event',
    () async {
      final gateway = _Gateway();
      final cubit = PushCubit(gateway);
      final opened = <PushNotificationData>[];
      var messages = 0;
      await cubit.initialize(onOpened: opened.add, onMessage: () => messages++);
      expect(cubit.state.token, 'token');
      expect(cubit.state.authorized, isTrue);
      expect(opened.single.data['taskId'], 'task');
      gateway.controller.add({
        'kind': 'opened',
        'data': {'threadId': 'thread'},
      });
      gateway.controller.add({
        'kind': 'message',
        'data': {'threadId': 'thread'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(opened.length, 2);
      expect(messages, 1);
      await cubit.close();
      await gateway.controller.close();
    },
  );
  test(
    'permission, retry and token rotation do not lose latest token',
    () async {
      final gateway = _Gateway()..authorized = false;
      final cubit = PushCubit(gateway);
      await cubit.initialize(onOpened: (_) {});
      expect(cubit.state.authorized, isFalse);
      await cubit.requestPermission();
      expect(cubit.state.authorized, isTrue);
      gateway.pending = Completer<String?>();
      final refresh = cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      gateway.controller.add({'kind': 'tokenChanged', 'token': 'new-token'});
      await Future<void>.delayed(Duration.zero);
      gateway.pending!.complete('old-token');
      await refresh;
      expect(cubit.state.token, 'new-token');
      expect(cubit.state.loading, isFalse);
      gateway.pending = null;
      gateway.fail = true;
      await cubit.refresh();
      expect(cubit.state.error, isNotNull);
      gateway.fail = false;
      await cubit.refresh();
      expect(cubit.state.error, isNull);
      await cubit.revokeToken();
      expect(cubit.state.token, isNull);
      expect(gateway.deleted, isTrue);
      await cubit.close();
      await gateway.controller.close();
    },
  );
  test(
    'iOS bridge requests permission without Android lifecycle channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('jospar/push_notifications');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'requestPermission' ? true : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final gateway = NativePushGateway();
      expect(gateway.supported, isTrue);
      await gateway.requestPermission();
      await gateway.bindAccount('ios-account');
      await gateway.clearAccount();
      expect(calls, ['requestPermission', 'bindAccount', 'clearAccount']);
    },
  );
  test('unsupported platforms never call native Firebase', () async {
    final gateway = _Gateway()..supported = false;
    final cubit = PushCubit(gateway);
    await cubit.initialize(onOpened: (_) {});
    await cubit.refresh();
    expect(gateway.statusCalls, 0);
    expect(cubit.state.supported, isFalse);
    await cubit.close();
    await gateway.controller.close();
  });
  test(
    'native bridge uses Android Firebase and existing permission channel',
    () async {
      final calls = <String>[];
      const channel = MethodChannel('jospar/push_notifications');
      const permission = MethodChannel('jospar/call_lifecycle');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'status' => {'authorized': true, 'channelEnabled': true},
          'token' => 'fcm',
          'initialMessage' => {'taskId': 'task'},
          _ => null,
        };
      });
      messenger.setMockMethodCallHandler(permission, (call) async {
        calls.add(call.method);
        return true;
      });
      final gateway = NativePushGateway();
      expect((await gateway.status())['authorized'], isTrue);
      expect(await gateway.token(), 'fcm');
      await gateway.initialMessage();
      await gateway.requestPermission();
      await gateway.openSettings();
      await gateway.deleteToken();
      expect(calls, [
        'status',
        'token',
        'initialMessage',
        'requestNotifications',
        'settings',
        'deleteToken',
      ]);
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(permission, null);
    },
  );
}

class _Gateway implements PushGateway {
  String? account;
  @override
  bool supported = true;
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  bool authorized = true, fail = false, deleted = false;
  int statusCalls = 0;
  Completer<String?>? pending;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  @override
  Future<Map<String, dynamic>> status() async {
    statusCalls++;
    if (fail) throw StateError('offline');
    return {'authorized': authorized, 'channelEnabled': true};
  }

  @override
  Future<String?> token() async => pending?.future ?? 'token';
  @override
  Future<Map<String, dynamic>?> initialMessage() async => {
    'messageId': 'initial',
    'taskId': 'task',
  };
  @override
  Future<void> requestPermission() async {
    authorized = true;
  }

  @override
  Future<void> openSettings() async {}
  @override
  Future<void> bindAccount(String userId) async {
    account = userId;
  }

  @override
  Future<void> clearAccount() async {}
  @override
  Future<void> deleteToken() async {
    deleted = true;
  }
}
