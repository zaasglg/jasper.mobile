import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';
import 'package:jospar/features/planner/presentation/widgets/task_schedule_sheet.dart';
import 'planner_test_app.dart';

const _preview = bool.fromEnvironment('PLANNER_DAY_PREVIEW');
final _previewKey = GlobalKey();
Future<void> _capture(WidgetTester tester, String name) async {
  if (!_preview) return;
  final boundary =
      _previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory('build/planner-day-preview').create(recursive: true);
    await File(
      'build/planner-day-preview/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
  });
}

class _Api implements HttpClientAdapter {
  final rows = <Map<String, dynamic>>[];
  final requests = <RequestOptions>[];
  bool oldServer = false;
  List<RequestOptions> get writes =>
      requests.where((request) => request.method != 'GET').toList();
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (oldServer &&
        (request.path.contains('/day-') || request.path.endsWith('/schedule'))) {
      return _json({}, 404);
    }
    if (request.method == 'GET') return _json(rows);
    final body = Map<String, dynamic>.from(request.data as Map);
    if (request.method == 'POST') {
      final row = {'id': 'entry', ...body};
      if (body['taskId'] != null) {
        row['task'] = {
          'id': body['taskId'],
          'projectId': 'p',
          'title': 'Проектная задача',
          'progress': 40,
        };
      }
      rows.add(row);
      return _json(row);
    }
    final row = rows.firstWhere(
      (row) => request.path.contains('/${row['id']}'),
    );
    row.addAll(body);
    if (body['scheduledAt'] != null && !body.containsKey('plannedDate')) {
      row['plannedDate'] = null;
    }
    return _json(row);
  }

  ResponseBody _json(Object value, [int status = 200]) =>
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

PlannerRepositoryImpl _repository(_Api api) =>
    PlannerRepositoryImpl(Dio()..httpClientAdapter = api);
Future<void> _flush(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<PlannerCubit> _show(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final cubit = PlannerCubit(_repository(api));
  addTearDown(cubit.close);
  await tester.runAsync(cubit.initialize);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: PlannerTestApp(
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider.value(value: cubit, child: const PlannerScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

Future<void> _saveEditor(WidgetTester tester) async {
  final save = find.byKey(const Key('planner-editor-save'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _flush(tester);
}

void main() {
  setUpAll(() async {
    if (!_preview) return;
    final font = ByteData.sublistView(
      await File('.codex/visual/project-board/Manrope.ttf').readAsBytes(),
    );
    for (final family in [
      'Manrope',
      for (final weight in [400, 500, 600, 700, 800]) 'Manrope_$weight',
    ]) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  test(
    'calendar dates round trip without timezone conversion and execution time can be cleared',
    () {
      final item = PlannerItemModel.fromJson({
        'id': 'day',
        'title': 'Day',
        'plannedDate': '2026-11-18T00:00:00.000Z',
        'scheduledAt': null,
        'completed': true,
      });
      expect(item.day, DateTime(2026, 11, 18));
      expect(item.scheduledAt, isNull);
      expect(item.toJson()['plannedDate'], '2026-11-18');
      expect(PlannerItemModel.fromJson(item.toJson()), item);
      final timed = item.copyWith(
        scheduledAt: plannerInstant(DateTime(2026, 11, 18), 12, 30),
      );
      final untimed = timed.copyWith(scheduledAt: null);
      expect(untimed.scheduledAt, isNull);
      expect(untimed.completed, isTrue);
    },
  );
  test(
    'day API persists a null start and date-only value for personal and linked entries',
    () async {
      final api = _Api();
      final repo = _repository(api);
      final day = DateTime(2026, 11, 18);
      await repo.create(
        title: 'Day',
        scheduledAt: null,
        plannedDate: day,
        durationMinutes: 30,
      );
      expect(api.writes.last.path, 'project-planner/account/day-tasks');
      expect(api.writes.last.data, {
        'title': 'Day',
        'scheduledAt': null,
        'plannedDate': '2026-11-18',
        'durationMinutes': 30,
      });
      await repo.addTask(
        projectId: 'p',
        taskId: 'task',
        scheduledAt: null,
        plannedDate: day,
        durationMinutes: 30,
      );
      expect(api.writes.last.path, 'project-planner/p/day-tasks');
      await repo.addTask(
        inboxTaskId: 'inbox',
        scheduledAt: null,
        plannedDate: day,
        durationMinutes: 30,
      );
      expect(api.writes.last.path, 'project-planner/account/day-inbox-tasks');
      final item = (await repo.load()).first;
      await repo.update(
        item,
        scheduledAt: null,
        plannedDate: DateTime(2026, 11, 19),
      );
      expect(api.writes.last.path, 'project-planner/items/entry/schedule');
      expect(api.writes.last.data, {
        'scheduledAt': null,
        'plannedDate': '2026-11-19',
      });
    },
  );
  test(
    'old servers cannot silently discard the calendar date or replace it with midnight',
    () async {
      final api = _Api()..oldServer = true;
      final repo = _repository(api);
      await expectLater(
        repo.create(
          title: 'Day',
          scheduledAt: null,
          plannedDate: DateTime(2026, 11, 18),
          durationMinutes: 30,
        ),
        throwsA(isA<PlannerException>()),
      );
      expect(api.requests, hasLength(1));
      expect(api.rows, isEmpty);
      await expectLater(
        repo.create(
          title: 'Missing day',
          scheduledAt: null,
          durationMinutes: 30,
        ),
        throwsA(isA<PlannerException>()),
      );
      expect(api.requests, hasLength(1));
    },
  );
  testWidgets(
    'new personal entries default to a calendar day without time and survive reload',
    (tester) async {
      final api = _Api();
      final cubit = await _show(tester, api);
      await tester.tap(find.byKey(const Key('planner-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-editor-time')), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'План на день');
      await tester.pumpAndSettle();
      await _capture(tester, 'add-without-time');
      await _saveEditor(tester);
      expect(api.writes.single.path, 'project-planner/account/day-tasks');
      expect(cubit.state.items.single.scheduledAt, isNull);
      expect(cubit.state.items.single.day, plannerDate(plannerNow()));
      await tester.runAsync(cubit.refresh);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('planner-unscheduled-entry')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('planner-agenda-entry')), findsNothing);
      await _capture(tester, 'day-without-time');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('project scheduling saves without time by default', (
    tester,
  ) async {
    final api = _Api();
    final cubit = PlannerCubit(_repository(api));
    addTearDown(cubit.close);
    await tester.runAsync(cubit.initialize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const TaskScheduleSheet(
                    title: 'Проектная задача',
                    source: 'Проект',
                    projectId: 'p',
                    taskId: 'task',
                  ),
                ),
              ),
              child: const Text('Планировать'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Планировать'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-time')), findsNothing);
    expect(api.writes, isEmpty);
    await tester.tap(find.byKey(const Key('schedule-confirm')));
    await _flush(tester);
    expect(api.writes.single.path, 'project-planner/p/day-tasks');
    expect(cubit.state.items.single.scheduledAt, isNull);
    expect(cubit.state.items.single.task!.progress, 40);
  });
  testWidgets('untimed plans are shown only on their chosen day', (
    tester,
  ) async {
    final today = plannerDate(plannerNow());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final api = _Api()
      ..rows.addAll([
        {
          'id': 'today',
          'title': 'Сегодняшний план',
          'plannedDate': plannerDayString(today),
        },
        {
          'id': 'tomorrow',
          'title': 'Завтрашний план',
          'plannedDate': plannerDayString(tomorrow),
        },
      ]);
    await _show(tester, api);
    expect(
      find.byKey(const ValueKey('planner-unscheduled-today')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-unscheduled-tomorrow')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('planner-next-day')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('planner-unscheduled-today')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('planner-unscheduled-tomorrow')),
      findsOneWidget,
    );
    expect(api.writes, isEmpty);
  });
  testWidgets(
    'tapping an untimed entry selects time and confirmation moves it to the agenda and back',
    (tester) async {
      final today = plannerDate(plannerNow());
      final api = _Api()
        ..rows.add({
          'id': 'entry',
          'title': 'Запись дня',
          'plannedDate': plannerDayString(today),
        });
      await _show(tester, api);
      await tester.tap(find.byKey(const ValueKey('planner-unscheduled-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      Navigator.of(
        tester.element(find.byType(TimePickerDialog)),
      ).pop(const TimeOfDay(hour: 14, minute: 30));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      await _saveEditor(tester);
      expect(
        api.rows.single['scheduledAt'],
        plannerInstant(today, 14, 30).toIso8601String(),
      );
      expect(
        find.byKey(const ValueKey('planner-unscheduled-entry')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('planner-agenda-entry')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('planner-item-menu-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Без времени'));
      await _flush(tester);
      expect(api.rows.single['scheduledAt'], isNull);
      expect(api.rows.single['plannedDate'], plannerDayString(today));
      expect(
        find.byKey(const ValueKey('planner-unscheduled-entry')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('planner-agenda-entry')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'an untimed entry can move to another day without assigning midnight',
    (tester) async {
      final today = plannerDate(plannerNow());
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final api = _Api()
        ..rows.add({
          'id': 'entry',
          'title': 'Перенос',
          'plannedDate': plannerDayString(today),
        });
      await _show(tester, api);
      await tester.tap(find.byKey(const ValueKey('planner-item-menu-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить день и запись'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planner-editor-date')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(tomorrow);
      await tester.pumpAndSettle();
      await _saveEditor(tester);
      expect(api.rows.single['scheduledAt'], isNull);
      expect(api.rows.single['plannedDate'], plannerDayString(tomorrow));
      expect(
        find.byKey(const ValueKey('planner-unscheduled-entry')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('planner-next-day')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('planner-unscheduled-entry')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'an outdated server keeps the unsaved draft and timed planning remains available',
    (tester) async {
      final api = _Api()..oldServer = true;
      await _show(tester, api);
      await tester.tap(find.byKey(const Key('planner-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Сохранить мой план',
      );
      await _saveEditor(tester);
      expect(find.byKey(const Key('planner-editor-save')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Сохранить мой план',
      );
      expect(api.rows, isEmpty);
      await tester.ensureVisible(
        find.byKey(const ValueKey('planner-mode-timed')),
      );
      await tester.tap(find.byKey(const ValueKey('planner-mode-timed')));
      await tester.pumpAndSettle();
      await _saveEditor(tester);
      expect(api.writes, hasLength(2));
      expect(api.rows.single['scheduledAt'], isNotNull);
      expect(find.byKey(const Key('planner-editor-save')), findsNothing);
    },
  );
  testWidgets('cancelling the time picker leaves an untimed entry unchanged', (
    tester,
  ) async {
    final api = _Api()
      ..rows.add({
        'id': 'entry',
        'title': 'Запись',
        'plannedDate': plannerDayString(plannerNow()),
      });
    await _show(tester, api);
    await tester.tap(find.byKey(const ValueKey('planner-unscheduled-entry')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('planner-unscheduled-entry')),
      findsOneWidget,
    );
    expect(api.writes, isEmpty);
  });
}
