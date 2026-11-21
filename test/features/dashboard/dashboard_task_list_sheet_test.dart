import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_task_list_sheet.dart';

void main() {
  testWidgets('allocation filters show matching task cards on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardTaskListSheet(
            title: 'Не распределено',
            allocationFilters: true,
            projects: [
              ProjectModel(
                id: 'p',
                code: 'P',
                name: 'Школа',
                workspaceId: 'w',
                start: null,
                end: null,
              ),
            ],
            tasks: [
              {
                'id': 'one',
                'projectId': 'p',
                'displayId': 'PR-1',
                'title': 'Без даты',
                'status': 'DONE',
                'progress': 0,
                'assignees': [
                  {'userId': 'u'},
                ],
              },
              {
                'id': 'two',
                'projectId': 'p',
                'displayId': 'PR-2',
                'title': 'Без исполнителя',
                'status': 'PROGRESS',
                'end': '2099-11-14',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Задачи · Не распределено'), findsOneWidget);
    expect(find.text('PR-1'), findsOneWidget);
    expect(find.text('PR-2'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    final filterBar = find.byType(SingleChildScrollView).last;
    await tester.tap(find.text('Без срока').first);
    await tester.pumpAndSettle();
    expect(find.text('PR-1'), findsOneWidget);
    expect(find.text('PR-2'), findsNothing);
    await tester.drag(filterBar, const Offset(-240, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Без участника').first);
    await tester.pumpAndSettle();
    expect(find.text('PR-1'), findsNothing);
    expect(find.text('PR-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
