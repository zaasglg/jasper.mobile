import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/collaboration/data/collaboration_models.dart';
import 'package:jospar/features/collaboration/data/project_participants_repository.dart';
import 'package:jospar/features/collaboration/domain/collaboration_repository.dart';
import 'package:jospar/features/collaboration/presentation/project_participants_cubit.dart';
import 'package:jospar/features/collaboration/presentation/project_participants_screen.dart';

void main() {
  late _Api api;
  late ProjectParticipantsRepository repository;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    api = _Api();
    repository = ProjectParticipantsRepository(Dio()..httpClientAdapter = api);
  });
  test(
    'flat members preserve project role, guest access, avatar and profile',
    () {
      final member = SpaceMember.fromJson({
        'id': 'guest',
        'name': 'Guest',
        'email': 'guest@test.dev',
        'role': 'ADMIN',
        'access': 'project',
        'avatarUrl': '/avatar.png',
        'about': 'Designer',
      });
      expect(member.userId, 'guest');
      expect(member.access, 'project');
      expect(member.avatarUrl, '/avatar.png');
      expect(SpaceMember.fromJson(member.toJson()), member);
      expect(member.copyWith(role: 'EXECUTOR').about, 'Designer');
    },
  );
  test(
    'roles come from project access, not global or workspace role',
    () async {
      api.role = 'ADMIN';
      final cubit = ProjectParticipantsCubit(repository, 'p');
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.roles, ['ADMIN', 'EXECUTOR']);
      expect(cubit.state.canEdit(cubit.state.members.first), false);
      api.role = 'EXECUTOR';
      await cubit.load();
      expect(cubit.state.canManage, false);
      var called = false;
      expect(
        await cubit.mutate(() async {
          called = true;
        }),
        false,
      );
      expect(called, false);
    },
  );
  test(
    'successful additions and invitations survive reload; failed mutation keeps list',
    () async {
      final cubit = ProjectParticipantsCubit(repository, 'p');
      addTearDown(cubit.close);
      await cubit.load();
      expect(
        await cubit.mutate(
          () => repository.add('p', ' Candidate@Test.dev ', 'ADMIN'),
        ),
        true,
      );
      expect(api.requests.where((r) => r.method == 'POST').last.data, {
        'email': 'candidate@test.dev',
        'role': 'ADMIN',
      });
      expect(cubit.state.members.length, 2);
      await cubit.load();
      expect(cubit.state.members.last.role, 'ADMIN');
      expect(
        await cubit.mutate(
          () => repository.add('p', 'new@test.dev', 'EXECUTOR'),
        ),
        true,
      );
      expect(cubit.state.invitations.single.email, 'new@test.dev');
      expect(cubit.state.members.length, 2);
      api.failWrites = true;
      expect(
        await cubit.mutate(
          () => repository.collaboration.removeMember(
            SpaceKind.project,
            'p',
            'candidate',
          ),
        ),
        false,
      );
      expect(cubit.state.members.length, 2);
      expect(cubit.state.saving, false);
      expect(cubit.state.error, contains('Недостаточно прав'));
    },
  );
  test(
    'link read does not create, scoped URL and role persist; errors retry',
    () async {
      expect(await repository.link('p'), isNull);
      expect(api.requests.single.path, 'projects/p/invite-link/current');
      final link = await repository.createLink('p', 'ADMIN');
      expect(link.url, 'https://orbita.test/join/project-token');
      expect(
        (await repository.changeLinkRole('p', 'EXECUTOR')).role,
        'EXECUTOR',
      );
      expect((await repository.link('p'))!.role, 'EXECUTOR');
      api.failLink = true;
      await expectLater(
        repository.link('p'),
        throwsA(isA<CollaborationException>()),
      );
      api.failLink = false;
      expect(await repository.link('p'), isNotNull);
      await repository.revokeLink('p');
      expect(await repository.link('p'), isNull);
      expect(api.requests.every((r) => r.path.startsWith('projects/p/')), true);
    },
  );
  test('email validation rejects whitespace and malformed addresses', () {
    for (final email in [
      'bad',
      'a@',
      'a b@test.dev',
      '@test.dev',
      'a@@test.dev',
      'a@b..dev',
      '.a@test.dev',
      'a..b@test.dev',
      'a@-test.dev',
      'a@test.d',
    ]) {
      expect(isInvitationEmail(email), false);
    }
    expect(isInvitationEmail(' user+tag@test.dev '), true);
  });
  testWidgets(
    'small screen and large text scroll without overflow; search marks existing access',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ProjectParticipantsScreen(id: 'p', repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Участники'), findsOneWidget);
      expect(
        find.text('Очень длинное название проекта для мобильного экрана'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('participants_add')));
      await tester.tap(find.byKey(const Key('participants_add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'admin');
      await tester.pumpAndSettle();
      expect(find.text('Доступ уже предоставлен'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('invalid email sends nothing, invitation updates pending list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectParticipantsScreen(id: 'p', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('participants_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.tap(find.text('Пригласить по email'));
    await tester.pumpAndSettle();
    expect(
      find.text('Введите корректный email или выберите пользователя.'),
      findsOneWidget,
    );
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
    await tester.enterText(find.byType(TextField), 'new@test.dev');
    await tester.tap(find.text('Пригласить по email'));
    await tester.pumpAndSettle();
    expect(api.invitations.single['email'], 'new@test.dev');
    expect(find.text('Ожидают приглашения: 1'), findsOneWidget);
  });
  test('repeated submission is blocked while saving', () async {
    final cubit = ProjectParticipantsCubit(repository, 'p');
    addTearDown(cubit.close);
    await cubit.load();
    final pending = Completer<void>();
    final first = cubit.mutate(() => pending.future);
    expect(cubit.state.saving, true);
    expect(await cubit.mutate(() async => fail('duplicate request')), false);
    pending.complete();
    expect(await first, true);
    expect(cubit.state.saving, false);
  });
  testWidgets(
    'large member lists render lazily and last member remains accessible',
    (tester) async {
      api.members.addAll(
        List.generate(
          80,
          (i) => {
            'id': 'member-$i',
            'name': 'Member $i',
            'email': 'member$i@test.dev',
            'role': 'EXECUTOR',
            'access': 'project',
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectParticipantsScreen(id: 'p', repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, lessThan(20));
      await tester.scrollUntilVisible(
        find.text('Member 79'),
        500,
        maxScrolls: 60,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Member 79'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('select existing user, change role, cancel removal and remove', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectParticipantsScreen(id: 'p', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('participants_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'candidate');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Candidate'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Добавить участника').last,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Добавить участника').last);
    await tester.pumpAndSettle();
    expect(find.text('Гость проекта'), findsOneWidget);
    await tester.tap(find.byTooltip('Действия участника'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор'));
    await tester.pumpAndSettle();
    expect(api.members.last['role'], 'ADMIN');
    await tester.tap(find.byTooltip('Действия участника'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить из проекта'));
    await tester.pumpAndSettle();
    expect(find.text('Candidate потеряет доступ к проекту.'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(api.members.length, 2);
    await tester.tap(find.byTooltip('Действия участника'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить из проекта'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(api.members.length, 1);
    expect(find.text('Candidate'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('link retry and copy use actual server URL', (tester) async {
    api.failLink = true;
    api.link = {
      'url': 'https://orbita.test/join/project-token',
      'role': 'EXECUTOR',
    };
    String? copied;
    String? shared;
    String? opened;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (call) async {
        shared = (call.arguments as Map)['text'] as String;
        return 'success';
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(urlChannel, (
      call,
    ) async {
      opened = (call.arguments as Map)['url'] as String;
      return true;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        urlChannel,
        null,
      );
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectParticipantsScreen(id: 'p', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Повторить'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    api.failLink = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Копировать'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Копировать'));
    await tester.pumpAndSettle();
    expect(copied, 'https://orbita.test/join/project-token');
    expect(find.text('Ссылка скопирована'), findsOneWidget);
    await tester.ensureVisible(find.text('Поделиться'));
    await tester.tap(find.text('Поделиться'));
    await tester.pumpAndSettle();
    expect(shared, copied);
    await tester.ensureVisible(find.byKey(const Key('participants_link_open')));
    await tester.tap(find.byKey(const Key('participants_link_open')));
    await tester.pumpAndSettle();
    expect(opened, copied);
  });
}

class _Api implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String role = 'SUPER_ADMIN';
  bool failWrites = false;
  bool failLink = false;
  Map<String, dynamic>? link;
  final members = <Map<String, dynamic>>[
    {
      'id': 'me',
      'name': 'Администратор с очень длинным именем',
      'email': 'admin@test.dev',
      'role': 'SUPER_ADMIN',
      'access': 'workspace',
    },
  ];
  final invitations = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(r);
    if (failWrites && r.method != 'GET') {
      return json({'message': 'Forbidden'}, 403);
    }
    if (r.path.contains('/invite-link')) {
      if (failLink) return json({'message': 'Offline'}, 503);
      if (r.method == 'POST') {
        link = {
          'url': 'https://orbita.test/join/project-token',
          'role': (r.data as Map)['role'],
        };
      }
      if (r.method == 'PATCH') link!['role'] = (r.data as Map)['role'];
      if (r.method == 'DELETE') link = null;
      return json(link);
    }
    if (r.path == 'users/me') return json({'id': 'me', 'role': 'EXECUTOR'});
    if (r.path.endsWith('/members/me')) return json({'role': role});
    if (r.path == 'workspaces/w/members') {
      return json([
        ...members,
        {
          'id': 'candidate',
          'name': 'Candidate',
          'email': 'candidate@test.dev',
          'role': 'EXECUTOR',
        },
      ]);
    }
    if (r.path.startsWith('projects/p/members/') && r.method != 'GET') {
      final id = r.path.split('/').last;
      if (r.method == 'PATCH') {
        members.firstWhere((m) => m['id'] == id)['role'] =
            (r.data as Map)['role'];
      }
      if (r.method == 'DELETE') members.removeWhere((m) => m['id'] == id);
      return json({'ok': true});
    }
    if (r.path == 'projects/p/members') {
      if (r.method == 'POST') {
        final data = Map<String, dynamic>.from(r.data as Map);
        if (data['email'] == 'candidate@test.dev') {
          members.add({
            'id': 'candidate',
            'name': 'Candidate',
            'access': 'project',
            ...data,
          });
        } else {
          invitations.add(data);
        }
      }
      return json({'members': members, 'pendingInvites': invitations});
    }
    return json({
      'id': 'p',
      'name': 'Очень длинное название проекта для мобильного экрана',
      'workspaceId': 'w',
    });
  }

  ResponseBody json(Object? value, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}
