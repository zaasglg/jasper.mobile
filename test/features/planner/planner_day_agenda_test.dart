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
  testWidgets('long gaps and task durations do not create empty grid space', (
    tester,
  ) async {
    await _show(tester, [
      _task('Вечерняя задача', 23),
      _task('Утренняя задача', 8),
    ]);
    final first = find.byKey(const ValueKey('planner-agenda-Утренняя задача'));
    final last = find.byKey(const ValueKey('planner-agenda-Вечерняя задача'));
    final morningTop = tester.getTopLeft(first).dy;
    final eveningTop = tester.getTopLeft(last).dy;
    expect(eveningTop - morningTop, lessThan(200));
    expect(last.hitTestable(), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
    expect(find.text('Сейчас'), findsOneWidget);
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
    expect(tester.getSize(first).height, originalHeight);
    expect(tester.takeException(), isNull);
  });

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
      expect(find.text('Google Календарь'), findsOneWidget);
      expect(find.text('Личное · Выполнено'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty day offers creation and remains pull-refreshable', (
    tester,
  ) async {
    var creates = 0;
    await _show(tester, [
      _task('other day', 8).copyWith(scheduledAt: DateTime(2026, 11, 15)),
      _task('all day', 9).copyWith(allDay: true),
      _task('archived', 10).copyWith(archived: true),
    ], onCreate: () => creates++);
    expect(find.byKey(const Key('planner-empty-title')), findsOneWidget);
    expect(find.text('other day'), findsNothing);
    await tester.tap(find.byKey(const Key('planner-empty-create')));
    expect(creates, 1);
    final list = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    expect(tester.takeException(), isNull);

    // A short viewport and large type must still allow reaching the action.
    await tester.binding.setSurfaceSize(const Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _show(tester, [], textScale: 1.6, onCreate: () => creates++);
    await tester.ensureVisible(find.byKey(const Key('planner-empty-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-empty-create')));
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
        find.text('Большой проект цифровизации университета'),
        findsOneWidget,
      );
      expect(find.text('Инбокс'), findsOneWidget);
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
    await tester.ensureVisible(find.byKey(const Key('planner-empty-create')));
    await tester.pumpAndSettle();
    await savePreview('empty-day-narrow');
  }, skip: !const bool.fromEnvironment('PLANNER_AGENDA_PREVIEW'));
}
