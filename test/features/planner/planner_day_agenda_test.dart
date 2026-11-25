import 'dart:async';
import 'package:jospar/features/planner/presentation/widgets/planner_untimed_list.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_day_agenda.dart';

final _day = DateTime(2026, 11, 14);
final _now = DateTime(2026, 11, 14, 9, 41);

PlannerItemModel _task(
  String id,
  int hour, {
  int duration = 30,
  bool external = false,
  bool completed = false,
}) => PlannerItemModel(
  id: id,
  title: id,
  scheduledAt: DateTime(2026, 11, 14, hour).toUtc(),
  durationMinutes: duration,
  external: external,
  completed: completed,
);

Future<void> _show(
  WidgetTester tester,
  List<PlannerItemModel> items, {
  Set<String> busyIds = const {},
  VoidCallback? onCreate,
  ValueChanged<PlannerItemModel>? onEdit,
  ValueChanged<PlannerItemModel>? onToggle,
  Future<bool> Function(PlannerItemModel, int)? onResize,
  void Function(PlannerItemModel, DateTime)? onSchedule,
  bool enableTaskDrag = false,
  double textScale = 1,
  Key? captureKey,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            key: captureKey,
            child: ColoredBox(
              color: Colors.white,
              child: PlannerDayAgenda(
                selectedDate: _day,
                now: _now,
                items: items,
                busyIds: busyIds,
                onCreate: onCreate ?? () {},
                onEdit: onEdit ?? (_) {},
                onToggle: onToggle ?? (_) {},
                onResize: onResize,
                onSchedule: onSchedule,
                enableUntimedDrag: enableTaskDrag,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Busy indicators intentionally keep animating.
  await tester.pump();
}

void main() {
  testWidgets(
    'timed drag scrolls at the finger edge and cancellation never saves',
    (tester) async {
      var drops = 0;
      await _show(
        tester,
        [for (var hour = 0; hour < 24; hour++) _task('move-$hour', hour)],
        enableTaskDrag: true,
        onSchedule: (_, _) => drops++,
      );
      final agenda = find.byKey(const Key('planner-day-agenda'));
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: agenda, matching: find.byType(Scrollable)).first,
      );
      final origin = tester.getCenter(
        find.byKey(const ValueKey('planner-open-move-8')),
      );
      final gesture = await tester.startGesture(origin);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        Offset(origin.dx, tester.getRect(agenda).bottom - 12),
      );
      await tester.pump();
      for (var tick = 0; tick < 20; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.position.pixels, greaterThan(0));
      expect(find.byKey(const Key('planner-drop-time')), findsOneWidget);
      expect(drops, 0);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(drops, 0);
      expect(find.byKey(const Key('planner-drop-time')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resize preview remains until save finishes and clears after failure',
    (tester) async {
      final pending = Completer<bool>();
      var saves = 0;
      await _show(
        tester,
        [_task('pending', 9)],
        onResize: (_, _) {
          saves++;
          return pending.future;
        },
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('planner-resize-pending'))),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(saves, 1);
      expect(find.byKey(const Key('planner-resize-preview')), findsOneWidget);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-resize-preview')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resizing near timeline edge scrolls without committing during tracking',
    (tester) async {
      var saves = 0;
      await _show(
        tester,
        [for (var hour = 0; hour < 24; hour++) _task('hour-$hour', hour)],
        onResize: (_, _) async {
          saves++;
          return true;
        },
      );
      final agenda = find.byKey(const Key('planner-day-agenda'));
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: agenda, matching: find.byType(Scrollable)).first,
      );
      final origin = tester.getCenter(
        find.byKey(const ValueKey('planner-resize-hour-8')),
      );
      final gesture = await tester.startGesture(origin);
      await gesture.moveTo(
        Offset(origin.dx, tester.getRect(agenda).bottom - 12),
      );
      await tester.pump();
      for (var tick = 0; tick < 20; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.position.pixels, greaterThan(0));
      expect(saves, 0);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resize clamps to fifteen minutes and the end of the selected day',
    (tester) async {
      final durations = <int>[];
      for (final (hour, delta, expected) in [
        (9, -10000.0, 15),
        (23, 10000.0, 60),
      ]) {
        await _show(
          tester,
          [_task('limit-$hour', hour)],
          onResize: (_, minutes) async {
            durations.add(minutes);
            return true;
          },
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey('planner-resize-limit-$hour'))),
        );
        await gesture.moveBy(Offset(0, delta));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(durations.last, expected);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('external and busy timeline entries have no resize handles', (
    tester,
  ) async {
    await _show(
      tester,
      [_task('external', 9, external: true), _task('saving', 12)],
      busyIds: const {'saving'},
      onResize: (_, _) async => true,
    );
    expect(find.byKey(const ValueKey('planner-resize-external')), findsNothing);
    expect(find.byKey(const ValueKey('planner-resize-saving')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drag near timeline edge scrolls and leaving cancels the preview',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final source = PlannerItemModel(
        id: 'all-day',
        title: 'Без времени',
        plannedDate: _day,
      );
      final items = [
        source,
        for (var i = 0; i < 48; i++)
          PlannerItemModel(
            id: 'busy-$i',
            title: 'Задача $i',
            scheduledAt: DateTime(
              _day.year,
              _day.month,
              _day.day,
              0,
              i * 30,
            ).toUtc(),
          ),
      ];
      var drops = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PlannerUntimedList(
                  items: [source],
                  busyIds: const {},
                  enableDrag: true,
                  onAssign: (_) {},
                  onMenu: (_) {},
                  onToggle: (_) {},
                ),
                Expanded(
                  child: PlannerDayAgenda(
                    selectedDate: _day,
                    now: _now,
                    items: items,
                    busyIds: const {},
                    onCreate: () {},
                    onEdit: (_) {},
                    onToggle: (_) {},
                    onSchedule: (_, _) => drops++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final agenda = find.byKey(const Key('planner-day-agenda'));
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: agenda, matching: find.byType(Scrollable)).first,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('planner-unscheduled-all-day')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final bounds = tester.getRect(agenda);
      await gesture.moveTo(Offset(250, bounds.bottom - 12));
      await tester.pump();
      for (var tick = 0; tick < 20; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.position.pixels, greaterThan(0));
      expect(find.byKey(const Key('planner-drop-time')), findsOneWidget);
      await gesture.moveTo(const Offset(5, 5));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(drops, 0);
      expect(find.byKey(const Key('planner-drop-time')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy and external all-day entries cannot start a drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlannerUntimedList(
            items: const [
              PlannerItemModel(id: 'busy', title: 'Сохраняется'),
              PlannerItemModel(id: 'google', title: 'Google', external: true),
            ],
            busyIds: const {'busy'},
            enableDrag: true,
            onAssign: (_) {},
            onMenu: (_) {},
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LongPressDraggable<PlannerItemModel>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'web scale fits gaps to viewport and gives occupied time readable height',
    (tester) async {
      await _show(tester, [
        _task('Вечерняя задача', 23),
        _task('Утренняя задача', 8),
      ]);
      final first = find.byKey(
        const ValueKey('planner-agenda-Утренняя задача'),
      );
      final last = find.byKey(const ValueKey('planner-agenda-Вечерняя задача'));
      final morningTop = tester.getTopLeft(first).dy;
      final eveningTop = tester.getTopLeft(last).dy;
      expect(eveningTop - morningTop, lessThan(600));
      expect(last.hitTestable(), findsOneWidget);
      for (final time in ['6:00', '9:00', '12:00', '15:00', '18:00']) {
        expect(find.text(time), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.byKey(const Key('planner-now-marker'))).dy,
        allOf(greaterThan(morningTop), lessThan(eveningTop)),
      );
      expect(find.byKey(const Key('planner-hour-9')), findsNothing);
      final originalHeight = tester.getSize(first).height;
      await _show(tester, [
        _task('Утренняя задача', 8, duration: 1440),
        _task('Вечерняя задача', 23, duration: 15),
      ]);
      expect(tester.getSize(first).height, greaterThan(originalHeight));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cards open and completion is disabled for busy or Google tasks',
    (tester) async {
      final opened = <String>[];
      final toggled = <String>[];
      await _show(
        tester,
        [
          _task('local', 8),
          _task('google', 9, external: true),
          _task('busy', 10),
          _task('done', 11, completed: true),
        ],
        busyIds: {'busy'},
        onEdit: (item) => opened.add(item.id),
        onToggle: (item) => toggled.add(item.id),
      );
      await tester.tap(find.byKey(const ValueKey('planner-open-local')));
      await tester.tap(find.byKey(const ValueKey('planner-complete-local')));
      await tester.tap(find.byKey(const ValueKey('planner-event-google')));
      await tester.tap(find.byKey(const ValueKey('planner-open-google')));
      await tester.tap(find.byKey(const ValueKey('planner-complete-busy')));
      await tester.tap(find.byKey(const ValueKey('planner-open-busy')));
      await tester.tap(find.byKey(const ValueKey('planner-complete-done')));
      expect(opened, ['local', 'google', 'google']);
      expect(toggled, ['local', 'done']);
      expect(
        find.byKey(const ValueKey('planner-complete-google')),
        findsNothing,
      );
      expect(find.text('google'), findsOneWidget);
      expect(find.text('done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timed tasks show their start time above the title', (
    tester,
  ) async {
    await _show(tester, [_task('start-time', 8)]);

    final time = find.byKey(const ValueKey('planner-time-start-time'));
    final title = find.text('start-time');

    expect(time, findsOneWidget);
    expect(tester.widget<Text>(time).data, '08:00');
    expect(
      tester.getTopLeft(time).dy,
      lessThan(tester.getTopLeft(title).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty day offers creation and remains pull-refreshable', (
    tester,
  ) async {
    var creates = 0;
    await _show(tester, [
      _task('other day', 8).copyWith(scheduledAt: DateTime(2026, 11, 15)),
      _task('all day', 9).copyWith(allDay: true),
      _task('archived', 10).copyWith(archived: true),
    ], onCreate: () => creates++);
    expect(find.text('6:00'), findsOneWidget);
    expect(find.text('other day'), findsNothing);
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('planner-timeline-create'))) +
          const Offset(250, 220),
    );
    expect(creates, 1);
    final list = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    expect(tester.takeException(), isNull);

    // A short viewport and large type must still allow reaching the action.
    await tester.binding.setSurfaceSize(const Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _show(tester, [], textScale: 1.6, onCreate: () => creates++);

    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('planner-timeline-create'))) +
          const Offset(250, 220),
    );
    expect(creates, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long titles and project names fit a narrow phone at large type',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _show(tester, [
        _task(
          'Подготовить подробный отчёт и согласовать результаты команды',
          9,
        ).copyWith(
          taskId: 'task',
          projectName: 'Большой проект цифровизации университета',
        ),
        _task('Из Инбокса', 10).copyWith(inboxTaskId: 'inbox'),
      ], textScale: 2);
      expect(
        find.textContaining(
          'Подготовить подробный отчёт и согласовать результаты команды',
        ),
        findsOneWidget,
      );
      expect(find.text('Из Инбокса'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('agenda visual preview', (tester) async {
    await tester.runAsync(() async {
      final font = ByteData.sublistView(
        await File('.codex/visual/project-board/Manrope.ttf').readAsBytes(),
      );
      for (final family in [
        'Manrope',
        'Manrope-Regular',
        'Manrope-Bold',
        'Manrope_regular',
        'Manrope_600',
        'Manrope_700',
      ]) {
        await (FontLoader(family)..addFont(Future.value(font))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
            rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
          ))
          .load();
    });
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final capture = GlobalKey();
    await _show(tester, [
      _task('Подготовить презентацию', 8).copyWith(completed: true),
      _task('Встреча с командой', 9, external: true),
      _task(
        'Проверить бюджет проекта',
        11,
      ).copyWith(taskId: 'JM-24', projectName: 'Развитие университета'),
      _task('Ответить на письма', 14).copyWith(inboxTaskId: 'inbox'),
      _task('Прогулка после работы', 18),
    ], captureKey: capture);
    await tester.pumpAndSettle();
    Future<void> savePreview(String name) async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/planner-preview').create(recursive: true);
        await File(
          'build/planner-preview/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await savePreview('day-agenda');
    await tester.binding.setSurfaceSize(const Size(390, 500));
    await _show(tester, [], captureKey: capture);
    await tester.pumpAndSettle();
    await savePreview('empty-day');
    await tester.binding.setSurfaceSize(const Size(320, 300));
    await _show(tester, [], textScale: 1.6, captureKey: capture);
    await tester.pumpAndSettle();

    await tester.pumpAndSettle();
    await savePreview('empty-day-narrow');
  }, skip: !const bool.fromEnvironment('PLANNER_AGENDA_PREVIEW'));
}
