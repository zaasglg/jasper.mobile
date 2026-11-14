import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_dates_sheet.dart';

void main() {
  testWidgets(
    'optional start validates and failed save keeps chosen date on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      DateTime? savedStart;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskDatesSheet(
              onSave: (start, end) async {
                calls++;
                savedStart = start;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        find.text('Выберите дату начала или отключите её.'),
        findsOneWidget,
      );
      expect(calls, 0);
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2026, 11, 13));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(savedStart, DateTime(2026, 11, 13));
      expect(
        find.text('Не удалось сохранить даты. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'time input preserves exact minutes and cancellation keeps date only',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DateTime? savedEnd;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskDatesSheet(
              end: DateTime(2026, 11, 15, 18, 37),
              onSave: (start, end) async {
                savedEnd = end;
                return false;
              },
            ),
          ),
        ),
      );
      final edit = find.byKey(const Key('task_time_edit'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final inputs = find.byType(TextField);
      await tester.enterText(inputs.at(0), '21');
      await tester.enterText(inputs.at(1), '43');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Готово'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(find.text('21:43 · Изменить'), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(savedEnd, DateTime(2026, 11, 15, 21, 43));
      final toggle = find.byKey(const Key('task_time_toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Только дата'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.text('Только дата'), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(savedEnd, DateTime(2026, 11, 15));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clear saves both dates as null', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTaskDatesSheet(
                context,
                start: DateTime(2026, 11, 12),
                end: DateTime(2026, 11, 13),
                onSave: (start, end) async {
                  cleared = start == null && end == null;
                  return true;
                },
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.byType(TaskDatesSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deadline-only mode hides optional start controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDatesSheet(
            allowStart: false,
            onSave: (start, end) async => true,
          ),
        ),
      ),
    );
    expect(find.text('Начало'), findsNothing);
    expect(find.text('СРОК'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });
}
