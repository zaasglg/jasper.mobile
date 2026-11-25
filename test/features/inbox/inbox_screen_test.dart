import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/inbox/presentation/screens/inbox_task_details_screen.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/inbox/presentation/cubit/inbox_cubit.dart';
import 'package:jospar/features/inbox/presentation/screens/inbox_screen.dart';

void main() {
  testWidgets('quick task input stays transparent in dark theme', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: QuickTaskComposer(
            controller: controller,
            focusNode: focusNode,
            isSubmitting: false,
            onChanged: (_) {},
            onAdd: () async {},
          ),
        ),
      ),
    );

    final input = tester.widget<TextField>(
      find.byKey(const Key('inbox-task-input')),
    );
    expect(input.decoration?.filled, isFalse);
  });

  testWidgets('swipe sorting keeps task until deletion is confirmed', (
    tester,
  ) async {
    final cubit = InboxCubit(_FakeInboxRepository())..addLocal('Разобрать');
    addTearDown(cubit.close);
    final task = cubit.state.tasks.single;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: InboxTaskRow(
              task: task,
              isCompleting: false,
              onToggle: () {},
            ),
          ),
        ),
      ),
    );
    final row = find.byKey(ValueKey('inbox-swipe-${task.id}'));
    await tester.drag(row, const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(find.text('Удалить'), findsOneWidget);
    expect(cubit.state.tasks, hasLength(1));
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить задачу?'), findsOneWidget);
    expect(cubit.state.tasks, hasLength(1));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(cubit.state.tasks, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy inbox row ignores swipes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InboxTaskRow(
            task: const InboxTaskModel(id: 'busy', title: 'Сохраняется'),
            isCompleting: true,
            onToggle: () {},
          ),
        ),
      ),
    );
    await tester.drag(find.byType(Dismissible), const Offset(-650, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Удалить'), findsNothing);
  });

  testWidgets('server inbox card offers menu and saves edited title', (
    tester,
  ) async {
    final repository = _FakeInboxRepository(
      initialTasks: const [
        InboxTaskModel(id: 'server-1', title: 'Исходная задача'),
      ],
    );
    final cubit = InboxCubit(repository)..load();
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const InboxScreen(showAppBar: false),
        ),
        GoRoute(
          path: '/inbox/:taskId',
          builder: (_, state) => InboxTaskDetailsScreen(
            taskId: state.pathParameters['taskId']!,
            initialTask: state.extra as InboxTaskModel,
            showAppBar: false,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inbox-task-actions-server-1')));
    await tester.pumpAndSettle();
    for (final label in [
      'Открыть карточку',
      'Изменить метки',
      'Изменить даты',
      'Переместить',
      'В ежедневник',
      'Копировать карточку',
      'Архивировать',
      'Удалить',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Открыть карточку'));
    await tester.pumpAndSettle();
    expect(find.byType(InboxTaskDetailsScreen), findsOneWidget);
    expect(find.text('Описание'), findsWidgets);
    await tester.tap(find.text('Исходная задача'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Исходная задача'),
      'Обновлённая задача',
    );
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.changes?['title'], 'Обновлённая задача');
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Исходная задача'));
    await tester.pumpAndSettle();
    expect(find.byType(InboxTaskDetailsScreen), findsOneWidget);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
        child: const MaterialApp(home: InboxScreen(showAppBar: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.byKey(const Key('inbox-empty-illustration')), findsOneWidget);
    expect(find.text('Инбокс разобран'), findsOneWidget);
    expect(find.text('Непрочитанные'), findsNothing);
    expect(find.text('Упоминания'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('inbox-task-input'))).dy,
      greaterThan(tester.getTopLeft(find.text('Инбокс разобран')).dy),
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
  });

  testWidgets(
    'empty illustration fits a constrained viewport with large text',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 180,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
                  child: InboxEmpty(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inbox-empty-illustration')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Инбокс разобран'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

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
        child: const MaterialApp(home: InboxScreen(showAppBar: false)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inbox-task-checkbox-server-1')));
    await tester.pumpAndSettle();

    expect(repository.completedTaskId, 'server-1');
    expect(find.text('Завершить меня'), findsNothing);
  });
}

class _FakeInboxRepository implements InboxRepository, InboxActionsRepository {
  _FakeInboxRepository({List<InboxTaskModel> initialTasks = const []})
    : _tasks = List<InboxTaskModel>.of(initialTasks);

  final List<InboxTaskModel> _tasks;
  String? completedTaskId;
  Map<String, dynamic>? changes;

  @override
  Future<void> updateTask(String id, Map<String, dynamic> changes) async {
    this.changes = changes;
  }

  @override
  Future<void> copyTask(InboxTaskModel task) async {}
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<void> moveTask(String id, String projectId) async {}

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
