import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_day_week_strip.dart';

void main() {
  testWidgets('highlights selected day, not today, and changes it on tap', (
    tester,
  ) async {
    var selected = DateTime(2026, 11, 24);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PlannerDayWeekStrip(
              selectedDate: selected,
              now: DateTime(2026, 11, 26),
              onSelected: (day) => setState(() => selected = day),
            ),
          ),
        ),
      ),
    );
    Finder semanticsFor(String key) => find
        .ancestor(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Semantics),
        )
        .first;
    expect(
      tester
          .widget<Semantics>(semanticsFor('planner-day-2026-11-24'))
          .properties
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<Semantics>(semanticsFor('planner-day-2026-11-26'))
          .properties
          .selected,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('planner-day-2026-11-26')));
    await tester.pump();
    expect(selected, DateTime(2026, 11, 26));
    expect(
      find.byKey(const ValueKey('planner-today-2026-11-26')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planner-today-2026-11-24')),
      findsNothing,
    );
    expect(
      tester
          .widget<Semantics>(semanticsFor('planner-day-2026-11-26'))
          .properties
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<Semantics>(semanticsFor('planner-day-2026-11-24'))
          .properties
          .selected,
      isFalse,
    );
  });
  testWidgets('week crosses year boundary and large text remains scrollable', (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 280,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: PlannerDayWeekStrip(
                  selectedDate: DateTime(2027, 1, 1),
                  onSelected: (day) => selected = day,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('planner-day-2026-12-28')),
      findsOneWidget,
    );
    final sunday = find.byKey(const ValueKey('planner-day-2027-01-03'));
    await tester.ensureVisible(sunday);
    await tester.tap(sunday);
    expect(selected, DateTime(2027, 1, 3));
    expect(tester.takeException(), isNull);
  });
}
