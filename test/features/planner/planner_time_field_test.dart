import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_time_field.dart';

void main() {
  testWidgets('wheel time is committed only with Done', (tester) async {
    var time = const TimeOfDay(hour: 9, minute: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PlannerTimeField(
              time: time,
              onChanged: (value) => setState(() => time = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PlannerTimeField));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2000, 1, 1, 14, 35));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(time, const TimeOfDay(hour: 9, minute: 0));
    expect(find.text('09:00'), findsOneWidget);
    await tester.tap(find.byType(PlannerTimeField));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2000, 1, 1, 14, 35));
    await tester.tap(find.byKey(const Key('planner-time-done')));
    await tester.pumpAndSettle();
    expect(time, const TimeOfDay(hour: 14, minute: 35));
    expect(find.text('14:35'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled field cannot open the picker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlannerTimeField(
            time: TimeOfDay(hour: 9, minute: 0),
            onChanged: null,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PlannerTimeField));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });
}
