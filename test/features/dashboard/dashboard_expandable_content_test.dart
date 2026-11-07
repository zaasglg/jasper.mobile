import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_expandable_content.dart';

void main() {
  testWidgets(
    'collapsed scope builds only preview rows and expands on demand',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardExpandableContent(child: _Rows()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Row 10'), findsNothing);
      await tester.tap(find.text('Показать всё'));
      await tester.pumpAndSettle();
      expect(find.text('Row 99'), findsOneWidget);
    },
  );
  testWidgets('long content expands, collapses and leaves page scrollable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardExpandableContent(
              child: SizedBox(height: 800, child: Text('Команда')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать всё'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-content-preview')))
          .height,
      360,
    );
    await tester.tap(find.text('Показать всё'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-content-preview')))
          .height,
      800,
    );
    await tester.ensureVisible(find.text('Свернуть'));
    await tester.tap(find.text('Свернуть'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-content-preview')))
          .height,
      360,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short content has no disclosure button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardExpandableContent(
            child: SizedBox(height: 120, child: Text('Короткий виджет')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Показать всё'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Rows extends StatelessWidget {
  const _Rows();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final index in DashboardPreviewScope.limit(
        context,
        List.generate(100, (index) => index),
      ))
        SizedBox(height: 48, child: Text('Row $index')),
    ],
  );
}
