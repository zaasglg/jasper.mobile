import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/inbox/presentation/cubit/inbox_cubit.dart';
import 'package:jospar/features/inbox/presentation/screens/inbox_screen.dart';

void main() {
  testWidgets('creates a quick inbox task on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = InboxCubit(_FakeInboxRepository())..load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<InboxCubit>.value(
        value: cubit,
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Инбокс'), findsOneWidget);
    expect(find.text('Неразобранные'), findsOneWidget);
    expect(find.text('Запишите первую задачу'), findsOneWidget);
    expect(find.text('Непрочитанные'), findsNothing);
    expect(find.text('Упоминания'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('inbox-task-input'))).dy,
      greaterThan(tester.getTopLeft(find.text('Запишите первую задачу')).dy),
    );

    await tester.enterText(
      find.byKey(const Key('inbox-task-input')),
      'Подготовить смету',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox-add-task')));
    await tester.pumpAndSettle();
    expect(find.text('Подготовить смету'), findsOneWidget);
    expect(find.text('Не распределена'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('completes a server inbox task by tapping its circle', (
    tester,
  ) async {
    final repository = _FakeInboxRepository(
      initialTasks: const <InboxTaskModel>[
        InboxTaskModel(id: 'server-1', title: 'Завершить меня'),
      ],
    );
    final cubit = InboxCubit(repository)..load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<InboxCubit>.value(
        value: cubit,
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inbox-task-checkbox-server-1')));
    await tester.pumpAndSettle();

    expect(repository.completedTaskId, 'server-1');
    expect(find.text('Завершить меня'), findsNothing);
  });
}

class _FakeInboxRepository implements InboxRepository {
  _FakeInboxRepository({List<InboxTaskModel> initialTasks = const []})
    : _tasks = List<InboxTaskModel>.of(initialTasks);

  final List<InboxTaskModel> _tasks;
  String? completedTaskId;

  @override
  Future<void> completeInboxTask({required String id}) async {
    completedTaskId = id;
    _tasks.removeWhere((task) => task.id == id);
  }

  @override
  Future<void> createInbox({required String title}) async {
    _tasks.insert(
      0,
      InboxTaskModel(id: 'created-${_tasks.length + 1}', title: title),
    );
  }

  @override
  Future<List<InboxTaskModel>> getInbox({
    bool archived = true,
    int sort = 1,
  }) async {
    return List<InboxTaskModel>.unmodifiable(_tasks);
  }
}
