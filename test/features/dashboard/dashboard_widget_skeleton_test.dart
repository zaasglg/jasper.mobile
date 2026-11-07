import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_widget_skeleton.dart';

void main() {
  for (final kind in ['team', 'resource', 'kpi-group', 'task-map']) {
    testWidgets('$kind skeleton fits compact cards and exposes loading label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: 160,
                child: DashboardWidgetSkeleton(kind: kind),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Загрузка виджета'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
        semantics.dispose();
    });
  }
}
