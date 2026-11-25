import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_date_picker.dart';

void main() {
  testWidgets(
    'Forui calendar commits the selected calendar day without UTC shift',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showPlannerDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 11, 23),
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.byType(FCalendar), findsOneWidget);
      await tester.tap(find.byKey(const Key('planner-calendar-next')));
      await tester.pumpAndSettle();
      expect(find.text('Декабрь 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('planner-calendar-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Ноябрь 2026'), findsOneWidget);

      await tester.tap(find.text('24').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('planner-date-done')));
      await tester.tap(find.byKey(const Key('planner-date-done')));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 11, 24));
      expect(result!.isUtc, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancel leaves the date unchanged', (tester) async {
    final initial = DateTime(2026, 11, 23);
    DateTime? result = initial;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showPlannerDatePicker(
                context: context,
                initialDate: initial,
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
