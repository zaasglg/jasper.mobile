import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_week_view.dart';

void main() {
  final monday = DateTime(2026, 11, 16);
  testWidgets('week shows source identity without task symbols', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlannerWeekView(
            selectedDate: monday,
            items: [
              PlannerItemModel(
                id: 'plain',
                title: 'Запись',
                icon: 'coffee',
                plannedDate: monday,
              ),
              PlannerItemModel(
                id: 'project',
                title: 'Настроить сервер',
                taskId: 'OR-20',
                icon: 'code',
                plannedDate: monday,
              ),
              PlannerItemModel(
                id: 'inbox',
                title: 'Из инбокса',
                inboxTaskId: 'inbox-id',
                plannedDate: monday,
              ),
            ],
            busyIds: const {},
            saving: false,
            onEdit: (_) {},
            onToggle: (_) {},
          ),
        ),
      ),
    );
    for (final mode in ['grid', 'list']) {
      await tester.tap(find.byKey(ValueKey('planner-week-$mode')));
      await tester.pumpAndSettle();
      expect(find.text('Запись'), findsOneWidget);
      expect(find.text('OR-20 Настроить сервер'), findsOneWidget);
      expect(find.text('Из инбокса'), findsOneWidget);
      expect(find.byIcon(LucideIcons.inbox), findsOneWidget);
      expect(find.byIcon(LucideIcons.coffee), findsNothing);
      expect(find.byIcon(LucideIcons.code), findsNothing);
      expect(find.byIcon(LucideIcons.listTodo), findsNothing);
    }
  });

  testWidgets('week surfaces follow theme changes in tiles and list', (
    tester,
  ) async {
    for (final dark in [false, true, false]) {
      final palette = AppPalette(dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: Scaffold(
            body: PlannerWeekView(
              key: ValueKey(dark),
              selectedDate: monday,
              items: [
                PlannerItemModel(
                  id: 'theme',
                  title: 'Задача',
                  plannedDate: monday,
                ),
              ],
              busyIds: const {},
              saving: false,
              onEdit: (_) {},
              onToggle: (_) {},
              onCreate: (_, _, _) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final task = find.byKey(const ValueKey('planner-week-item-theme'));
      expect(tester.widget<Material>(task).color, palette.subtleSurface);
      final card = tester.widget<Container>(
        find.byKey(const ValueKey('planner-week-day-2026-11-16')),
      );
      expect(
        (card.decoration! as BoxDecoration).border,
        Border.all(color: palette.border),
      );
      final input = find.byKey(const ValueKey('planner-week-input-2026-11-16'));
      final surfaces = tester.widgetList<Container>(
        find.ancestor(of: input, matching: find.byType(Container)),
      );
      expect(
        surfaces.any(
          (surface) =>
              surface.decoration is BoxDecoration &&
              (surface.decoration! as BoxDecoration).color ==
                  palette.subtleSurface,
        ),
        isTrue,
      );
      final grid = tester.widget<IconButton>(
        find.byKey(const ValueKey('planner-week-grid')),
      );
      expect(
        grid.style!.backgroundColor!.resolve({WidgetState.selected}),
        palette.subtleSurface,
      );
      await tester.tap(find.byKey(const ValueKey('planner-week-list')));
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(task).color, Colors.transparent);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'web all-day timestamps keep their local calendar day and appear in week',
    (tester) async {
      final webItem = PlannerItemModel.fromJson({
        'id': 'web-day',
        'title': 'rgrg',
        'scheduledAt': monday.toUtc().toIso8601String(),
        'hasTime': false,
        'archived': false,
      });
      expect(webItem.scheduledAt, isNull);
      expect(webItem.day, monday);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlannerWeekView(
              selectedDate: monday,
              items: [webItem],
              busyIds: const {},
              saving: false,
              onEdit: (_) {},
              onToggle: (_) {},
              onCreate: (_, _, _) async => true,
            ),
          ),
        ),
      );
      expect(find.text('rgrg'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('planner-week-day-2026-11-16')),
        findsOneWidget,
      );
      expect(find.text('00:00'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('week groups dated tasks and switches tiles to list', (
    tester,
  ) async {
    String? toggled, opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlannerWeekView(
            selectedDate: monday,
            saving: false,
            busyIds: const {},
            items: [
              PlannerItemModel(
                id: 'a',
                title: 'Первая задача',
                plannedDate: monday,
              ),
              PlannerItemModel(
                id: 'b',
                title: 'Вторая задача',
                plannedDate: monday,
                scheduledAt: DateTime(2026, 11, 16, 9),
              ),
              PlannerItemModel(
                id: 'archived',
                title: 'Архив',
                plannedDate: monday,
                archived: true,
              ),
              const PlannerItemModel(id: 'undated', title: 'Без даты'),
            ],
            onToggle: (item) => toggled = item.id,
            onEdit: (item) => opened = item.id,
            onCreate: (_, _, _) async => true,
          ),
        ),
      ),
    );
    final a = find.byKey(const ValueKey('planner-week-item-a'));
    final b = find.byKey(const ValueKey('planner-week-item-b'));
    expect(tester.getTopLeft(a).dy, tester.getTopLeft(b).dy);
    expect(tester.getSize(a).height, tester.getSize(b).height);
    expect(find.text('Без даты'), findsNothing);
    expect(find.text('Архив'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('planner-week-list')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(b).dy, greaterThan(tester.getTopLeft(a).dy));
    expect(tester.getSize(a).height, tester.getSize(b).height);
    await tester.longPress(a);
    expect(toggled, 'a');
    await tester.tap(find.text('Первая задача'));
    expect(opened, 'a');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('planner-week-day-2026-11-22')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('planner-week-day-2026-11-22')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'quick add uses its card date and preserves failed input at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <(DateTime, String, TimeOfDay?)>[];
        var success = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: PlannerWeekView(
                selectedDate: monday.add(const Duration(days: 2)),
                items: const [],
                busyIds: const {},
                saving: false,
                onEdit: (_) {},
                onToggle: (_) {},
                onCreate: (day, title, time) async {
                  calls.add((day, title, time));
                  return success;
                },
              ),
            ),
          ),
        );
        const key = ValueKey('planner-week-input-2026-11-16');
        final input = find.byKey(key);
        await tester.enterText(input, '  План на понедельник  ');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
        expect(calls.single, (monday, 'План на понедельник', null));
        expect(
          tester.widget<TextField>(input).controller!.text,
          contains('План на понедельник'),
        );
        expect(
          find.text('Не удалось добавить. Повторите попытку.'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('planner-week-time-2026-11-16')),
        );
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.byType(TimePickerDialog)),
        ).pop(const TimeOfDay(hour: 9, minute: 45));
        await tester.pumpAndSettle();
        success = true;
        await tester.tap(
          find.byKey(const ValueKey('planner-week-submit-2026-11-16')),
        );
        await tester.pumpAndSettle();
        expect(calls.last, (
          monday,
          'План на понедельник',
          const TimeOfDay(hour: 9, minute: 45),
        ));
        expect(tester.widget<TextField>(input).controller!.text, isEmpty);
        await tester.tap(find.byTooltip('Весь день'));
        await tester.enterText(input, 'Весь день');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
        expect(calls.last, (monday, 'Весь день', null));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
