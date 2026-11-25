import 'planner_test_app.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/planner/data/models/google_calendar_models.dart';
import 'package:jospar/features/planner/data/repositories/google_calendar_repository_impl.dart';
import 'package:jospar/features/planner/domain/repositories/google_calendar_repository.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/google_calendar_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';

GoogleCalendarEvent event(
  String id, {
  String start = '2026-10-10T04:00:00Z',
  String? end = '2026-10-10T05:00:00Z',
  bool allDay = false,
}) => GoogleCalendarEvent(
  id: id,
  title: id,
  startsAt: start,
  endsAt: end,
  allDay: allDay,
);
void main() {
  test(
    'Google API contract, all pages, deduplication and shared disconnect',
    () async {
      final adapter = _Adapter();
      final repo = GoogleCalendarRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
          ..httpClientAdapter = adapter,
      );
      expect((await repo.status()).canWrite, isTrue);
      expect((await repo.authorizationUrl()).host, 'accounts.google.com');
      final items = await repo.events(
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 11, 1),
        includeHolidays: false,
      );
      expect(items.map((e) => e.id), ['one', 'two']);
      final requests = adapter.requests
          .where((r) => r.path.endsWith('/events'))
          .toList();
      expect(requests.length, 2);
      expect(requests.first.queryParameters, {
        'timeMin': '2026-10-01T00:00:00.000Z',
        'timeMax': '2026-11-01T00:00:00.000Z',
        'includeHolidays': false,
        'take': 50,
      });
      expect(requests.last.queryParameters['pageToken'], 'next');
      await repo.disconnect();
      expect(adapter.requests.last.path, 'google-drive/disconnect');
      expect(adapter.requests.last.method, 'DELETE');
    },
  );
  test('repeated pagination cursor fails instead of hanging', () async {
    final adapter = _Adapter()..repeat = true;
    final repo = GoogleCalendarRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter,
    );
    await expectLater(
      repo.events(DateTime.utc(2026, 10, 1), DateTime.utc(2026, 11, 1)),
      throwsA(isA<PlannerException>()),
    );
  });
  test('all-day dates use device midnight and exclusive end', () {
    final items = event(
      'day',
      start: '2026-10-10',
      end: '2026-10-12',
      allDay: true,
    ).entries(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
    expect(items.length, 2);
    expect(items.first.scheduledAt, DateTime(2026, 10, 10).toUtc());
    expect(items.last.scheduledAt, DateTime(2026, 10, 11).toUtc());
    expect(
      items.every((e) => e.external && e.allDay && e.durationMinutes == 1440),
      isTrue,
    );
  });
  test('timed events spanning midnight split into read-only day slices', () {
    final items = event(
      'night',
      start: DateTime(2026, 10, 10, 23, 30).toUtc().toIso8601String(),
      end: DateTime(2026, 10, 11, 1).toUtc().toIso8601String(),
    ).entries(DateTime(2026, 10, 10), DateTime(2026, 10, 12));
    expect(items.map((e) => e.durationMinutes), [30, 60]);
    expect(items.every((e) => e.external), isTrue);
    expect(plannerLocal(items.last.scheduledAt!).hour, 0);
  });
  test(
    'connection from website loads events; disconnect clears them',
    () async {
      final repo = _Repo();
      final cubit = GoogleCalendarCubit(repo);
      await cubit.range(DateTime(2026, 10, 10));
      expect(cubit.state.connection.canWrite, isTrue);
      expect(cubit.state.events.length, 1);
      cubit.showEvents(false);
      expect(cubit.state.showEvents, isFalse);
      await cubit.holidays(false);
      expect(repo.holidays, isFalse);
      await cubit.disconnect();
      expect(cubit.state.events, isEmpty);
      expect(cubit.state.connection.connected, isFalse);
      await cubit.close();
    },
  );
  test(
    'disconnected status never queries events and errors remain visible',
    () async {
      final repo = _Repo()..connected = false;
      final cubit = GoogleCalendarCubit(repo);
      await cubit.range(DateTime(2026, 10, 10));
      expect(repo.loads, 0);
      repo.fail = true;
      await cubit.refresh();
      expect(cubit.state.error, isNotNull);
      await cubit.close();
    },
  );
  test('late previous month response cannot overwrite current month', () async {
    final repo = _Repo();
    final cubit = GoogleCalendarCubit(repo);
    final first = Completer<List<GoogleCalendarEvent>>();
    repo.pending = first;
    final old = cubit.range(DateTime(2026, 10, 10));
    await Future<void>.delayed(Duration.zero);
    repo.pending = null;
    await cubit.range(DateTime(2026, 11, 10));
    first.complete([event('old')]);
    await old;
    expect(cubit.state.events.single.id, 'current');
    await cubit.close();
  });
  testWidgets(
    'planner renders Google events and opens read-only details and settings',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = plannerNow();
      final repo = _Repo()
        ..result = [
          event(
            'Google встреча',
            start: plannerInstant(now, 9, 0).toIso8601String(),
            end: plannerInstant(now, 10, 0).toIso8601String(),
          ),
        ];
      sl.registerSingleton<GoogleCalendarRepository>(repo);
      addTearDown(() => sl.unregister<GoogleCalendarRepository>());
      await tester.pumpWidget(
        PlannerTestApp(child: const MaterialApp(home: PlannerScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Google встреча'), findsOneWidget);
      expect(find.byKey(const Key('planner-today')), findsNothing);
      final sources = find.byKey(const Key('planner-calendar-sources'));
      final datePicker = find.byKey(const Key('planner-date-picker'));
      expect(sources, findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: sources),
        findsNothing,
      );
      for (final size in [
        const Size(320, 568),
        const Size(360, 800),
        const Size(390, 844),
        const Size(800, 900),
        const Size(400, 900),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(tester.getCenter(sources).dy, tester.getCenter(datePicker).dy);
        final previous = find.byKey(const Key('planner-previous-day'));
        final navigationY = tester.getCenter(previous).dy;
        for (final control in [
          previous,
          find.byKey(const Key('planner-view-selector')),
          find.byKey(const Key('planner-next-day')),
        ]) {
          expect(tester.getCenter(control).dy, navigationY);
          expect(tester.getTopLeft(control).dx, greaterThanOrEqualTo(0));
          expect(tester.getTopRight(control).dx, lessThanOrEqualTo(size.width));
        }
        if ((navigationY - tester.getCenter(datePicker).dy).abs() < 1) {
          expect(
            tester.getTopLeft(previous).dx,
            greaterThanOrEqualTo(tester.getTopRight(datePicker).dx),
          );
        } else {
          expect(navigationY, greaterThan(tester.getBottomLeft(datePicker).dy));
        }
        expect(tester.takeException(), isNull);
      }
      expect(
        find.byKey(const ValueKey('planner-complete-current')),
        findsNothing,
      );
      await tester.tap(find.text('Google встреча'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('События Google редактируются'),
        findsOneWidget,
      );
      expect(find.text('Сохранить'), findsNothing);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Источники календаря'));
      await tester.pumpAndSettle();
      expect(find.text('Подключено'), findsOneWidget);
      expect(find.text('Показывать события Google'), findsOneWidget);
      await tester.pumpWidget(PlannerTestApp(child: const SizedBox()));
    },
  );
}

class _Repo implements GoogleCalendarRepository {
  bool connected = true, fail = false, holidays = true;
  int loads = 0;
  Completer<List<GoogleCalendarEvent>>? pending;
  List<GoogleCalendarEvent> result = [event('current')];
  @override
  Future<GoogleCalendarStatus> status() async {
    if (fail) throw const PlannerException('Сеть недоступна');
    return GoogleCalendarStatus(connected: connected, canWrite: connected);
  }

  @override
  Future<List<GoogleCalendarEvent>> events(
    DateTime start,
    DateTime end, {
    bool includeHolidays = true,
  }) async {
    loads++;
    holidays = includeHolidays;
    return pending?.future ?? result;
  }

  @override
  Future<Uri> authorizationUrl() async =>
      Uri.parse('https://accounts.google.com/o/oauth2/v2/auth?state=opaque');
  @override
  Future<void> disconnect() async {
    connected = false;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool repeat = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final second = options.queryParameters['pageToken'] != null;
    final Object data = options.path.endsWith('/status')
        ? {'connected': true, 'canWrite': true}
        : options.path.endsWith('/auth')
        ? {'url': 'https://accounts.google.com/o/oauth2/v2/auth?state=opaque'}
        : options.path.endsWith('/events')
        ? {
            'items': [event('one').toJson(), if (second) event('two').toJson()],
            'nextPageToken': second && !repeat ? null : 'next',
          }
        : {};
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
