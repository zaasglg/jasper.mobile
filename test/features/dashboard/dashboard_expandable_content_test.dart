import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_expandable_content.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_collapsible_widget.dart';

void main() {
  testWidgets('expanded card keeps its height after scrolling away and back', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: ListView.builder(
            controller: scroll,
            itemCount: 12,
            itemBuilder: (context, index) => index == 0
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: DashboardCollapsibleWidget(
                      title: 'Команда',
                      icon: Icons.people,
                      child: DashboardExpandableContent(child: _Rows()),
                    ),
                  )
                : const SizedBox(height: 400),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать всё'));
    await tester.pumpAndSettle();
    final preview = find.byType(DashboardExpandableContent);
    final height = tester.getSize(preview).height;
    expect(height, greaterThan(360));
    final state = tester.state(preview);
    scroll.jumpTo(6500);
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pump();
    expect(tester.state(preview), same(state));
    expect(tester.getSize(preview).height, height);
    expect(find.text('Row 99'), findsOneWidget);
    expect(find.text('Показать всё'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
