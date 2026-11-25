import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_model.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_task_picker.dart';

void main() {
  const task = ProjectTaskModel(
    id: 'project',
    projectId: 'p',
    status: 'TODO',
    title: 'Подготовить отчёт',
    displayId: 'PR-42',
  );
  const inbox = InboxTaskModel(
    id: 'mail',
    title: 'Ответить на письмо',
    displayId: 'IN-7',
  );

  testWidgets('searches by code and title, then returns the original task', (
    tester,
  ) async {
    Object? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Выбрать'),
              onPressed: () async =>
                  selected = await showModalBottomSheet<Object>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        const PlannerTaskPicker(tasks: [task], inbox: [inbox]),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    expect(find.text('PR-42 · Проект'), findsOneWidget);
    expect(find.text('IN-7 · Инбокс'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('planner-task-search')),
      'pr-42',
    );
    await tester.pumpAndSettle();
    expect(find.text(task.title), findsOneWidget);
    expect(find.text(inbox.title), findsNothing);
    await tester.enterText(
      find.byKey(const Key('planner-task-search')),
      'неизвестная',
    );
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('planner-task-search')),
      'письмо',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planner-pick-inbox-mail')));
    await tester.pumpAndSettle();
    expect(selected, same(inbox));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'archived and local-only tasks are excluded from the empty state',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlannerTaskPicker(
              tasks: [
                ProjectTaskModel(
                  id: 'archived',
                  projectId: 'p',
                  status: 'TODO',
                  title: 'Archive',
                  archived: true,
                ),
              ],
              inbox: [
                InboxTaskModel(id: 'local', title: 'Local', isLocalOnly: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Нет доступных задач'), findsOneWidget);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Local'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picker fits with keyboard and larger text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              viewInsets: EdgeInsets.only(bottom: 300),
              textScaler: TextScaler.linear(1.6),
            ),
            child: PlannerTaskPicker(tasks: [task], inbox: [inbox]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-task-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
