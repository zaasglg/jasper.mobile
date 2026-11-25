import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_scrum_widget.dart';

void main() {
  testWidgets('scrum typography fits narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: DashboardScrumWidget(
                userId: 'u',
                onOpenTask: (_) async {},
                projects: const [
                  ProjectModel(
                    id: 'p',
                    code: 'P',
                    name: 'Очень длинное название строительного проекта',
                    workspaceId: 'w',
                    start: null,
                    end: null,
                  ),
                ],
                metadata: const {
                  'columns': [
                    {
                      'projectId': 'p',
                      'name': 'Очень длинное название колонки выполнения работ',
                      'statusMap': 'DONE',
                      'color': '#00aa66',
                    },
                  ],
                },
                tasks: List.generate(
                  300,
                  (i) => {
                    'id': '$i',
                    'projectId': 'p',
                    'status': 'DONE',
                    'progress': 100,
                    'assigneeId': 'u',
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('300 из 300 выполнено'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrum counts completion independently of column placement and filters mine',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardScrumWidget(
                userId: 'u',
                onOpenTask: (_) async {},
                projects: const [
                  ProjectModel(
                    id: 'p',
                    code: 'P',
                    name: 'Школа',
                    workspaceId: 'w',
                    start: null,
                    end: null,
                  ),
                ],
                metadata: const {
                  'columns': [
                    {
                      'projectId': 'p',
                      'name': 'Готово',
                      'statusMap': 'DONE',
                      'color': '#00aa66',
                    },
                    {
                      'projectId': 'p',
                      'name': 'Разработка',
                      'statusMap': 'PROGRESS',
                      'color': '#6D5FE0',
                    },
                  ],
                  'epics': [
                    {
                      'projectId': 'p',
                      'id': 'e',
                      'name': 'Этап 1',
                      'color': '#6D5FE0',
                    },
                  ],
                },
                tasks: const [
                  {
                    'id': 'one',
                    'projectId': 'p',
                    'status': 'DONE',
                    'progress': 0,
                    'assigneeId': 'u',
                    'epics': [
                      {'epicId': 'e'},
                    ],
                  },
                  {
                    'id': 'two',
                    'projectId': 'p',
                    'status': 'PROGRESS',
                    'progress': 100,
                    'assignees': [
                      {'userId': 'other'},
                    ],
                  },
                  {
                    'id': 'three',
                    'projectId': 'p',
                    'status': 'PROGRESS',
                    'progress': 0,
                    'assigneeId': 'other',
                    'end': '2020-01-01',
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('1 из 3 выполнено'), findsOneWidget);
      expect(find.text('Разработка'), findsOneWidget);
      await tester.tap(find.text('Только мои задачи'));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 из 1 выполнено'), findsOneWidget);
      await tester.tap(find.byTooltip('Группировка скрама'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-option-epic')));
      await tester.tap(find.text('Готово').last);
      await tester.pumpAndSettle();
      expect(find.text('Этап 1'), findsOneWidget);
      expect(find.text('Разработка'), findsNothing);
      await tester.tap(find.text('Этап 1'));
      await tester.pumpAndSettle();
      expect(find.text('Задачи · Этап 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
