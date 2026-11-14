import 'planner_test_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';

void main() {
  testWidgets('shows Trello-style planner and changes the selected day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PlannerTestApp(child: const MaterialApp(home: PlannerScreen())),
    );

    expect(find.text('Ежедневник'), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('Нет задач со сроком'), findsOneWidget);
    expect(find.text('GMT+5'), findsNothing);
    expect(find.text('09'), findsOneWidget);

    final selectedDate = find.byKey(const Key('planner-selected-date'));
    final initialText = tester.widget<Text>(selectedDate).data;

    await tester.tap(find.byKey(const Key('planner-next-day')));
    await tester.pumpAndSettle();

    final nextDayText = tester.widget<Text>(selectedDate).data;
    expect(nextDayText, isNot(initialText));
    expect(find.byKey(const Key('planner-today')), findsNothing);
    await tester.tap(find.byKey(const Key('planner-date-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
