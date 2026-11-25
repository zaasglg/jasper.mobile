import 'package:jospar/features/planner/domain/utils/planner_day_scale.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_date_picker.dart';
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
  bool rejectTimeChange = false;
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
        (request.path.contains('/day-') ||
            request.path.endsWith('/schedule') ||
            (request.data is Map && request.data['hasTime'] == false))) {
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
    if (rejectTimeChange && body['scheduledAt'] != null) {
      return _json({'message': 'Schedule rejected'}, 400);
    }
    final row = rows.firstWhere(
      (row) => request.path.contains('/${row['id']}'),
    );
    row.addAll(body);
    if (body['scheduledAt'] != null && !body.containsKey('plannedDate')) {
      row['plannedDate'] = null;
      row['hasTime'] = body['hasTime'] ?? true;
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
  testWidgets(
    'timed task moves from 10 to 14:30 through adaptive occupied slots on release',
    (tester) async {
      final day = plannerDate(plannerNow());
      final api = _Api()
        ..rows.addAll([
          {
            'id': 'move-slot',
            'title': 'Перенести встречу',
            'taskId': 'source-task',
            'projectId': 'project',
            'durationMinutes': 30,
            'scheduledAt': DateTime(
              day.year,
              day.month,
              day.day,
              10,
            ).toUtc().toIso8601String(),
          },
          {
            'id': 'occupied',
            'title': 'Другая задача',
            'durationMinutes': 60,
            'scheduledAt': DateTime(
              day.year,
              day.month,
              day.day,
              14,
            ).toUtc().toIso8601String(),
          },
        ]);
      await _show(tester, api);
      final agenda = find.byKey(const Key('planner-day-agenda'));
      final rect = tester.getRect(agenda);
      final scale = PlannerDayScale([
        (start: 600.0, end: 630.0),
        (start: 840.0, end: 900.0),
      ], rect.height);
      final source = find.byKey(const ValueKey('planner-agenda-move-slot'));
      final origin = tester.getCenter(
        find.byKey(const ValueKey('planner-open-move-slot')),
      );
      final anchorY = origin.dy - tester.getTopLeft(source).dy + 2;
      final gesture = await tester.startGesture(origin);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        Offset(origin.dx, rect.top + scale.toY(870) + anchorY),
      );
      await tester.pump();
      expect(find.byKey(const Key('planner-drop-time')), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(api.writes, isEmpty);
      await gesture.up();
      await _flush(tester);
      expect(api.writes, hasLength(1));
      final write = api.writes.single;
      expect(write.method, 'PATCH');
      expect(write.path, 'project-planner/items/move-slot');
      expect(
        write.data['scheduledAt'],
        DateTime(
          day.year,
          day.month,
          day.day,
          14,
          30,
        ).toUtc().toIso8601String(),
      );
      expect(write.data['durationMinutes'], 30);
      expect((write.data as Map).containsKey('title'), isFalse);
      expect(api.rows, hasLength(2));
      expect(source, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'holding and releasing a non-quarter-hour task does not change its time',
    (tester) async {
      final day = plannerDate(plannerNow());
      final original = DateTime(
        day.year,
        day.month,
        day.day,
        10,
        7,
      ).toUtc().toIso8601String();
      final api = _Api()
        ..rows.add({
          'id': 'hold-only',
          'title': 'Только зажать',
          'durationMinutes': 45,
          'scheduledAt': original,
        });
      await _show(tester, api);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('planner-open-hold-only'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await _flush(tester);
      expect(api.writes, isEmpty);
      expect(api.rows.single['scheduledAt'], original);
      final sideways = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('planner-open-hold-only'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await sideways.moveBy(const Offset(40, 0));
      await tester.pump();
      await sideways.up();
      await _flush(tester);
      expect(api.writes, isEmpty);
      expect(api.rows.single['scheduledAt'], original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled timed-slot drag leaves the original schedule intact', (
    tester,
  ) async {
    final day = plannerDate(plannerNow());
    final api = _Api()
      ..rows.add({
        'id': 'cancel-slot',
        'title': 'Отменить перенос',
        'scheduledAt': DateTime(
          day.year,
          day.month,
          day.day,
          10,
        ).toUtc().toIso8601String(),
      });
    await _show(tester, api);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('planner-open-cancel-slot'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(Offset(240, tester.getTopLeft(find.text('15:00')).dy));
    await tester.pump();
    expect(find.byKey(const Key('planner-drop-time')), findsOneWidget);
    await gesture.cancel();
    await _flush(tester);
    expect(api.writes, isEmpty);
    expect(find.byKey(const Key('planner-drop-time')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed timed-slot move keeps original time and permits retry', (
    tester,
  ) async {
    final day = plannerDate(plannerNow());
    final original = DateTime(
      day.year,
      day.month,
      day.day,
      10,
    ).toUtc().toIso8601String();
    final api = _Api()
      ..rejectTimeChange = true
      ..rows.add({
        'id': 'failed-slot',
        'title': 'Повторить перенос',
        'scheduledAt': original,
        'durationMinutes': 30,
      });
    await _show(tester, api);
    final source = find.byKey(const ValueKey('planner-open-failed-slot'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(Offset(240, tester.getTopLeft(find.text('15:00')).dy));
    await tester.pump();
    await gesture.up();
    await _flush(tester);
    expect(api.writes, hasLength(1));
    expect(api.rows.single['scheduledAt'], original);
    expect(
      find.byKey(const ValueKey('planner-timed-drag-failed-slot')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resizing keeps the adaptive scale fixed and saves duration once on release',
    (tester) async {
      final day = plannerDate(plannerNow());
      final start = DateTime(day.year, day.month, day.day, 9).toUtc();
      final api = _Api()
        ..rows.add({
          'id': 'resize-me',
          'title': 'Изменить длительность',
          'taskId': 'original-task',
          'projectId': 'project',
          'scheduledAt': start.toIso8601String(),
          'durationMinutes': 30,
        });
      await _show(tester, api);
      final card = find.byKey(const ValueKey('planner-agenda-resize-me'));
      final before = tester.getRect(card);
      final noonY = tester.getTopLeft(find.text('12:00')).dy;
      final gapRate = (noonY - before.bottom - 2) / 150;
      final handle = find.byKey(const ValueKey('planner-resize-resize-me'));
      final task = find.byKey(const ValueKey('planner-agenda-resize-me'));
      expect(
        tester.getCenter(handle).dx,
        closeTo(tester.getCenter(task).dx, 0.01),
      );
      final origin = tester.getCenter(handle);
      final gesture = await tester.startGesture(origin);
      await gesture.moveTo(origin + Offset(0, gapRate * 30));
      await tester.pump();
      expect(find.text('60 мин'), findsOneWidget);
      expect(tester.getTopLeft(find.text('12:00')).dy, closeTo(noonY, .1));
      expect(
        tester.getRect(card).bottom - before.bottom,
        closeTo(gapRate * 30, .1),
      );
      expect(api.writes, isEmpty);
      await gesture.up();
      await _flush(tester);
      expect(api.writes, hasLength(1));
      expect(api.writes.single.method, 'PATCH');
      expect(api.writes.single.path, 'project-planner/items/resize-me');
      expect(api.writes.single.data['durationMinutes'], 60);
      expect(api.writes.single.data['scheduledAt'], start.toIso8601String());
      expect((api.writes.single.data as Map).containsKey('title'), isFalse);
      expect(find.byKey(const Key('planner-resize-preview')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled resize writes nothing and restores original size', (
    tester,
  ) async {
    final day = plannerDate(plannerNow());
    final api = _Api()
      ..rows.add({
        'id': 'cancel-resize',
        'title': 'Отменить размер',
        'scheduledAt': DateTime(
          day.year,
          day.month,
          day.day,
          9,
        ).toUtc().toIso8601String(),
        'durationMinutes': 30,
      });
    await _show(tester, api);
    final card = find.byKey(const ValueKey('planner-agenda-cancel-resize'));
    final size = tester.getSize(card);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('planner-resize-cancel-resize')),
      ),
    );
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(find.byKey(const Key('planner-resize-preview')), findsOneWidget);
    await gesture.cancel();
    await _flush(tester);
    expect(api.writes, isEmpty);
    expect(tester.getSize(card), size);
    expect(find.byKey(const Key('planner-resize-preview')), findsNothing);
  });

  testWidgets('failed resize restores duration and leaves handle available', (
    tester,
  ) async {
    final day = plannerDate(plannerNow());
    final api = _Api()
      ..rejectTimeChange = true
      ..rows.add({
        'id': 'failed-resize',
        'title': 'Ошибка размера',
        'scheduledAt': DateTime(
          day.year,
          day.month,
          day.day,
          9,
        ).toUtc().toIso8601String(),
        'durationMinutes': 30,
      });
    await _show(tester, api);
    final card = find.byKey(const ValueKey('planner-agenda-failed-resize'));
    final size = tester.getSize(card);
    final handle = find.byKey(const ValueKey('planner-resize-failed-resize'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 45));
    await tester.pump();
    await gesture.up();
    await _flush(tester);
    expect(api.writes, hasLength(1));
    expect(tester.getSize(card), size);
    expect(handle, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timed task can be dragged into an empty all-day area without duplicating',
    (tester) async {
      final day = plannerDate(plannerNow());
      final api = _Api()
        ..rows.add({
          'id': 'back-to-day',
          'title': 'Вернуть на весь день',
          'taskId': 'source-task',
          'projectId': 'project',
          'durationMinutes': 60,
          'scheduledAt': DateTime(
            day.year,
            day.month,
            day.day,
            9,
          ).toUtc().toIso8601String(),
        });
      await _show(tester, api);
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('planner-open-back-to-day')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final target = find.byKey(
        ValueKey('planner-all-day-drop-${plannerDayString(day)}'),
      );
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      expect(find.text('Отпустите: весь день'), findsOneWidget);
      expect(api.writes, isEmpty);
      await gesture.up();
      await _flush(tester);
      expect(api.writes, hasLength(1));
      final write = api.writes.single;
      expect(write.method, 'PATCH');
      expect(write.path, 'project-planner/items/back-to-day');
      expect(
        write.data['scheduledAt'],
        plannerInstant(day, 0, 0).toIso8601String(),
      );
      expect(write.data['hasTime'], isFalse);
      expect(write.data['durationMinutes'], 60);
      expect(
        find.byKey(const ValueKey('planner-unscheduled-back-to-day')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('planner-agenda-back-to-day')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled return to all-day performs no write', (tester) async {
    final day = plannerDate(plannerNow());
    final api = _Api()
      ..rows.add({
        'id': 'cancel-return',
        'title': 'Оставить время',
        'scheduledAt': DateTime(
          day.year,
          day.month,
          day.day,
          9,
        ).toUtc().toIso8601String(),
      });
    await _show(tester, api);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('planner-open-cancel-return')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(ValueKey('planner-all-day-drop-${plannerDayString(day)}')),
      ),
    );
    await tester.pump();
    await gesture.cancel();
    await _flush(tester);
    expect(api.writes, isEmpty);
    expect(
      find.byKey(const ValueKey('planner-agenda-cancel-return')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed return to all-day preserves timed entry', (tester) async {
    final day = plannerDate(plannerNow());
    final api = _Api()
      ..oldServer = true
      ..rows.add({
        'id': 'failed-return',
        'title': 'Не терять время',
        'scheduledAt': DateTime(
          day.year,
          day.month,
          day.day,
          9,
        ).toUtc().toIso8601String(),
      });
    await _show(tester, api);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('planner-open-failed-return')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(ValueKey('planner-all-day-drop-${plannerDayString(day)}')),
      ),
    );
    await tester.pump();
    await gesture.up();
    await _flush(tester);
    expect(api.writes, hasLength(1));
    expect(
      find.byKey(const ValueKey('planner-agenda-failed-return')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-unscheduled-failed-return')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drag all-day entry onto adaptive timeline saves its existing id only on release',
    (tester) async {
      final day = plannerDate(plannerNow());
      final api = _Api()
        ..rows.add({
          'id': 'drag-me',
          'taskId': 'original-task',
          'projectId': 'project',
          'title': 'Перенести на время',
          'hasTime': false,
          'plannedDate': plannerDayString(day),
          'durationMinutes': 45,
        });
      api.rows.add({
        'id': 'morning',
        'title': 'Утренняя встреча',
        'scheduledAt': DateTime(
          day.year,
          day.month,
          day.day,
          9,
        ).toUtc().toIso8601String(),
        'durationMinutes': 60,
      });
      await _show(tester, api);
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('planner-unscheduled-drag-me')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final y = tester.getTopLeft(find.text('12:00')).dy;
      await gesture.moveTo(Offset(230, y));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const Key('planner-drop-time')), findsOneWidget);
      expect(api.writes, isEmpty);
      await gesture.up();
      await _flush(tester);
      expect(api.writes, hasLength(1));
      final write = api.writes.single;
      expect(write.method, 'PATCH');
      expect(write.path, 'project-planner/items/drag-me');
      expect(
        write.data['scheduledAt'],
        DateTime(day.year, day.month, day.day, 12).toUtc().toIso8601String(),
      );
      expect(write.data['durationMinutes'], 45);
      expect((write.data as Map).containsKey('title'), isFalse);
      expect(
        find.byKey(const ValueKey('planner-unscheduled-drag-me')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('planner-agenda-drag-me')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'releasing an all-day drag outside timeline cancels without a write',
    (tester) async {
      final api = _Api()
        ..rows.add({
          'id': 'cancel-drag',
          'title': 'Оставить на весь день',
          'hasTime': false,
          'plannedDate': plannerDayString(plannerNow()),
        });
      await _show(tester, api);
      final source = find.byKey(
        const ValueKey('planner-unscheduled-cancel-drag'),
      );
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        Offset(230, tester.getTopLeft(find.text('12:00')).dy),
      );
      await tester.pump();
      await gesture.moveTo(const Offset(100, 45));
      await tester.pump();
      await gesture.up();
      await _flush(tester);
      expect(api.writes, isEmpty);
      expect(source, findsOneWidget);
      expect(find.byKey(const Key('planner-drop-time')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed time change keeps all-day source available for retry', (
    tester,
  ) async {
    final api = _Api()
      ..rejectTimeChange = true
      ..rows.add({
        'id': 'failed-drag',
        'title': 'Не терять задачу',
        'hasTime': false,
        'plannedDate': plannerDayString(plannerNow()),
      });
    await _show(tester, api);
    final source = find.byKey(
      const ValueKey('planner-unscheduled-failed-drag'),
    );
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(Offset(230, tester.getTopLeft(find.text('12:00')).dy));
    await tester.pump();
    await gesture.up();
    await _flush(tester);
    expect(api.writes, hasLength(1));
    expect(source, findsOneWidget);
    expect(
      find.byKey(const ValueKey('planner-agenda-failed-drag')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

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
    'personal entries use hasTime while linked entries keep their separate contract',
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
      expect(api.writes.last.path, 'project-planner/account/tasks');
      expect(api.writes.last.data, {
        'title': 'Day',
        'scheduledAt': plannerInstant(day, 0, 0).toIso8601String(),
        'hasTime': false,
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
      expect(api.writes.last.path, 'project-planner/items/entry');
      expect(api.writes.last.data, {
        'scheduledAt': plannerInstant(
          DateTime(2026, 11, 19),
          0,
          0,
        ).toIso8601String(),
        'hasTime': false,
      });
    },
  );
  test(
    'standard endpoint preserves an untimed day and rejects a missing day',
    () async {
      final api = _Api();
      final repo = _repository(api);
      await repo.create(
        title: 'Day',
        scheduledAt: null,
        plannedDate: DateTime(2026, 11, 18),
        durationMinutes: 30,
      );
      expect(api.requests, hasLength(1));
      final restored = (await repo.load()).single;
      expect(restored.scheduledAt, isNull);
      expect(restored.day, DateTime(2026, 11, 18));
      api.requests.clear();
      await expectLater(
        repo.create(
          title: 'Missing day',
          scheduledAt: null,
          durationMinutes: 30,
        ),
        throwsA(isA<PlannerException>()),
      );
      expect(api.requests, isEmpty);
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
      expect(api.writes.single.path, 'project-planner/account/tasks');
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
      await tester.tap(find.text('Весь день').last);
      await _flush(tester);
      expect(
        api.rows.single['scheduledAt'],
        plannerInstant(today, 0, 0).toIso8601String(),
      );
      expect(api.rows.single['hasTime'], isFalse);
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
      Navigator.of(
        tester.element(find.byType(PlannerDatePickerDialog)),
      ).pop(tomorrow);
      await tester.pumpAndSettle();
      await _saveEditor(tester);
      expect(
        api.rows.single['scheduledAt'],
        plannerInstant(tomorrow, 0, 0).toIso8601String(),
      );
      expect(api.rows.single['hasTime'], isFalse);
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
