import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/chat/presentation/widgets/shared_task_message.dart';
import 'package:jospar/features/kanban/presentation/widgets/task_card.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/domain/repositories/task_details_repository.dart';

class _Tasks implements TaskDetailsRepository {
  bool fail = false;
  final calls = <String>[];
  @override
  Future<TaskDetailsPayload> getTask(String taskId) async {
    calls.add(taskId);
    if (fail) throw const TaskDetailsException('Ошибка сети');
    return TaskDetailsPayload(
      task: ProjectTaskModel.fromJson({
        'id': taskId,
        'projectId': 'project',
        'status': 'TODO',
        'displayId': 'ПР-96',
        'title': 'Batyrkhan exam',
        'end': '2026-10-12T10:00:00Z',
        'epics': [
          {'id': 'e', 'name': 'Релиз', 'color': '#26855c'},
        ],
        'detail': {
          'labels': [
            {'id': 'l', 'text': 'Проверить'},
          ],
          'files': [
            {'id': 'f'},
          ],
          'comments': [
            {'id': 'c'},
          ],
        },
      }),
      detail: const TaskDetailModel(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('recognizes shared task links and preserves surrounding message text', () {
    final link = sharedTaskLink(
      'Посмотри [ПР-96: Batyrkhan exam](https://jospar.me/tasks?view=kanban&taskId=task&project=project) сегодня',
      null,
    )!;
    expect(link.taskId, 'task');
    expect(link.title, 'Batyrkhan exam');
    expect(link.displayId, 'ПР-96');
    expect(link.before, 'Посмотри ');
    expect(link.after, ' сегодня');
    expect(
      sharedTaskLink('https://example.test/tasks?taskId=task', null),
      isNull,
    );
    expect(
      sharedTaskLink('https://jospar.me/tasks?taskId=task', null)!.taskId,
      'task',
    );
  });

  testWidgets('loads the shared board card and opens task details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Tasks();
    sl.registerSingleton<TaskDetailsRepository>(repository);
    addTearDown(() => sl.unregister<TaskDetailsRepository>());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(36),
              child: SharedTaskMessage(
                taskId: 'task',
                projectId: 'project',
                title: 'Старое название',
                displayId: 'ПР-96',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/tasks/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Задача ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('Batyrkhan exam'), findsOneWidget);
    expect(find.text('Релиз'), findsOneWidget);
    expect(find.text('Проверить'), findsOneWidget);
    expect(repository.calls, ['task']);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Batyrkhan exam'));
    await tester.pumpAndSettle();
    expect(find.text('Задача task'), findsOneWidget);
  });

  testWidgets('retains linked title on failure and supports retry', (
    tester,
  ) async {
    final repository = _Tasks()..fail = true;
    sl.registerSingleton<TaskDetailsRepository>(repository);
    addTearDown(() => sl.unregister<TaskDetailsRepository>());
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SharedTaskMessage(
            taskId: 'task',
            projectId: 'project',
            title: 'Название из ссылки',
            displayId: 'ПР-96',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Название из ссылки'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Batyrkhan exam'), findsOneWidget);
    expect(repository.calls, ['task', 'task']);
  });
}
