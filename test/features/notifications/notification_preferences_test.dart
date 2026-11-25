import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/features/notifications/domain/entities/notification_preferences.dart';
import 'package:jospar/features/notifications/domain/notification_preferences_repository.dart';
import 'package:jospar/features/notifications/domain/push_gateway.dart';
import 'package:jospar/features/notifications/presentation/notification_preferences_cubit.dart';
import 'package:jospar/features/notifications/presentation/notification_preferences_section.dart';
import 'package:jospar/features/notifications/presentation/push_cubit.dart';

String jwt(String id) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.signature';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'categories are independent and quiet hours cross midnight with exclusive end',
    () {
      const p = NotificationPreferences(messages: false, quietEnabled: true);
      expect(p.allows('message', DateTime(2026, 1, 1, 12)), false);
      expect(p.allows('mention', DateTime(2026, 1, 1, 12)), true);
      expect(p.allows('deadline', DateTime(2026, 1, 1, 22)), false);
      expect(p.isQuiet(DateTime(2026, 1, 2, 7, 59)), true);
      expect(p.isQuiet(DateTime(2026, 1, 2, 8)), false);
      expect(p.allows('call', DateTime(2026, 1, 1, 23)), true);
      expect(
        p
            .copyWith(quietStart: 480, quietEnd: 480)
            .isQuiet(DateTime(2026, 1, 1, 12)),
        true,
      );
      expect(NotificationPreferences.fromJson(p.toJson()), p);
      expect(
        NotificationPreferences.fromJson({
          'quietStart': -1,
          'quietEnd': 2000,
        }).quietStart,
        1320,
      );
    },
  );
  late _Repository repository;
  late AuthTokenStorage tokens;
  late PushCubit push;
  late NotificationPreferencesCubit cubit;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tokens = AuthTokenStorage(const FlutterSecureStorage());
    await tokens.save(jwt('a'));
    authSession.markAuthenticated();
    repository = _Repository();
    push = PushCubit(_Gateway());
    await push.refresh();
    push.registrationStatus(true);
    cubit = NotificationPreferencesCubit(repository, tokens, push);
  });
  tearDown(() async {
    await cubit.close();
    await push.close();
  });
  test(
    'persists per account, restores choices and reports unsynced server',
    () async {
      await cubit.load();
      repository.failServer = true;
      await cubit.update(cubit.state.value.copyWith(messages: false));
      expect(cubit.state.value.messages, false);
      expect(cubit.state.error, isNotNull);
      repository.failServer = false;
      await cubit.synchronize();
      expect(cubit.state.error, isNull);
      await tokens.save(jwt('b'));
      await cubit.load();
      expect(cubit.state.owner, 'b');
      expect(cubit.state.value.messages, true);
      await tokens.save(jwt('a'));
      await cubit.load();
      expect(cubit.state.value.messages, false);
    },
  );
  test('late sync cannot replace a newer choice', () async {
    final pending = Completer<void>();
    repository.pending = pending;
    final loading = cubit.load();
    await Future<void>.delayed(Duration.zero);
    final changing = cubit.update(cubit.state.value.copyWith(mentions: false));
    pending.complete();
    await loading;
    await changing;
    expect(cubit.state.value.mentions, false);
    expect(repository.sent.last.mentions, false);
  });
  test('failed local save retains old values and allows retry', () async {
    await cubit.load();
    repository.failSave = true;
    await cubit.update(cubit.state.value.copyWith(deadlines: false));
    expect(cubit.state.value.deadlines, true);
    expect(cubit.state.saving, false);
    repository.failSave = false;
    await cubit.update(cubit.state.value.copyWith(deadlines: false));
    expect(cubit.state.value.deadlines, false);
  });
  testWidgets('compact settings show categories and editable quiet hours', (
    tester,
  ) async {
    await tester.runAsync(cubit.load);
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NotificationPreferencesSection(cubit: cubit),
          ),
        ),
      ),
    );
    expect(find.text('Сообщения'), findsOneWidget);
    expect(find.text('Упоминания'), findsOneWidget);
    await tester.tap(find.text('Тихие часы'));
    await tester.pumpAndSettle();
    expect(find.text('22:00'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements NotificationPreferencesRepository {
  final cache = <String, NotificationPreferences>{};
  final sent = <NotificationPreferences>[];
  bool failServer = false, failSave = false;
  Completer<void>? pending;
  @override
  NotificationPreferences read(String owner) =>
      cache[owner] ?? const NotificationPreferences();
  @override
  Future<void> save(String owner, NotificationPreferences p) async {
    if (failSave) throw StateError('failed');
    cache[owner] = p;
  }

  @override
  Future<String> applyNative(String owner, Map<String, dynamic> p) async =>
      'Asia/Almaty';
  @override
  Future<void> synchronize(
    String jwt,
    String token,
    Map<String, dynamic> p,
  ) async {
    final wait = pending;
    pending = null;
    await wait?.future;
    if (failServer) throw StateError('offline');
    sent.add(NotificationPreferences.fromJson(p));
  }
}

class _Gateway implements PushGateway {
  @override
  bool get supported => true;
  @override
  Future<Map<String, dynamic>> status() async => {'authorized': true};
  @override
  Future<String?> token() async => 'device-token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
