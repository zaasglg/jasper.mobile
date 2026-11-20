import 'package:jospar/features/dashboard/domain/entities/dashboard_widget_options.dart';
import 'package:flutter/material.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/cubit/dashboard_layout_cubit.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_resource_options.dart';
import 'dashboard_layout_test.dart' show FakeDashboardRepository;

void main() {
  testWidgets(
    'resource settings retain per-project choices while switching projects',
    (tester) async {
      final cubit = DashboardLayoutCubit(FakeDashboardRepository());
      await cubit.configure('u', 'w');
      addTearDown(cubit.close);
      var project = 'p1';
      Map<String, dynamic> changes = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => project = project == 'p1' ? 'p2' : 'p1'),
                    child: const Text('Другой проект'),
                  ),
                  DashboardResourceOptions(
                    cubit: cubit,
                    projects: const [],
                    projectId: project,
                    options: const DashboardWidgetOptions(
                      resourceFilterType: 'projects',
                      resourceModeByProject: {'p1': 'all', 'p2': 'all'},
                      resourceNamesByProject: {
                        'p1': ['["План","Факт"]'],
                        'p2': [],
                      },
                    ),
                    onChanged: (value) => changes = value,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mode = find
          .byWidgetPredicate((e) => e is DashboardSelectorField<String>)
          .last;
      await tester.tap(mode);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Прогресс задач').last);
      await tester.tap(find.text('Готово').last);
      await tester.pumpAndSettle();
      expect(changes['resourceModeByProject']['p1'], 'tasks');
      await tester.tap(find.text('Другой проект'));
      await tester.pumpAndSettle();
      expect(changes['resourceModeByProject']['p2'], 'all');
      expect(changes['resourceModeByProject']['p1'], 'tasks');
      expect(changes['resourceNamesByProject']['p1'], ['["План","Факт"]']);
      await tester.tap(find.text('Другой проект'));
      await tester.pumpAndSettle();
      expect(find.text('Прогресс задач'), findsOneWidget);
      expect(changes['resourceModeByProject']['p1'], 'tasks');
      expect(tester.takeException(), isNull);
    },
  );
}
