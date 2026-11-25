import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/core/widgets/task_completion_indicator.dart';

void main() {
  testWidgets('completion is green and busy state replaces the check', (
    tester,
  ) async {
    Future<void> show({bool completed = true, bool busy = false}) =>
        tester.pumpWidget(
          MaterialApp(
            home: TaskCompletionIndicator(completed: completed, busy: busy),
          ),
        );
    await show();
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TaskCompletionIndicator),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((container.decoration! as BoxDecoration).color, AppColors.success);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await show(busy: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await show(completed: false);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
