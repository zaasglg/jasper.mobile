import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:jospar/features/projects/domain/entities/task_epic_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_data.dart';
import 'package:jospar/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/tasks/domain/entities/kanban_column_model.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/projects/domain/repositories/project_task_repository.dart';
import 'package:jospar/features/projects/presentation/screens/project_epics_screen.dart';
import 'package:jospar/features/tasks/domain/repositories/task_details_repository.dart';

const _active = TaskEpicModel(id: 'active', name: 'Запуск', color: '#123456');
const _empty = TaskEpicModel(id: 'empty', name: 'Идеи', color: '#123456');
const _done = TaskEpicModel(id: 'done', name: 'Релиз', color: '#123456');

class _Repository
    implements
        TaskDetailsRepository,
        TaskExtrasRepository,
        ProjectEpicCreationRepository,
        ProjectTaskRepository {
  bool fail = false;
  bool failCreate = false;
  final created = <TaskEpicModel>[];
  String? createdProject;

  @override
  Future<void> createEpic({
    required String projectId,
    required String name,
    required String color,
  }) async {
    if (failCreate) {
      throw const TaskDetailsException('Не удалось создать эпик.');
    }
    createdProject = projectId;
    created.add(TaskEpicModel(id: 'new', name: name, color: color));
  }

  @override
  Future<List<TaskEpicModel>> getEpics(String projectId) async {
    if (fail) throw Exception('Offline');
    return [_active, _empty, _done, ...created];
  }

  @override
  Future<List<ProjectTaskModel>> getTasksForProjectIds(
    List<String> ids,
  ) async => [
    const ProjectTaskModel(
      id: '1',
      projectId: 'p',
      status: 'TODO',
      title: 'Подготовка',
      epics: [_active],
    ),
    const ProjectTaskModel(
      id: '2',
      projectId: 'p',
      status: 'DONE',
      progress: 100,
      title: 'Готово',
      epics: [_done],
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repository repository;
  setUp(() {
    repository = _Repository();
    sl.registerSingleton<TaskDetailsRepository>(repository);
    sl.registerSingleton<ProjectTaskRepository>(repository);
  });
  tearDown(() => sl.reset());

  testWidgets('epic checkboxes filter the board and clear restores tasks', (
    tester,
  ) async {
    final cubit = KanbanCubit(_BoardRepository(repository));
    addTearDown(cubit.close);
    await cubit.load('p');
    const todo = KanbanColumnModel(
      id: 'todo',
      name: 'К работе',
      statusMap: 'TODO',
    );
    const done = KanbanColumnModel(
      id: 'done',
      name: 'Готово',
      statusMap: 'DONE',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectEpicsScreen(projectId: 'p', boardCubit: cubit),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('epic-filter-active')));
    await tester.pumpAndSettle();
    expect(cubit.state.epicFilterIds, {'active'});
    expect(cubit.state.tasksFor(todo).map((task) => task.id), ['1']);
    expect(cubit.state.tasksFor(done), isEmpty);
    await tester.tap(find.byKey(const ValueKey('epic-filter-done')));
    await tester.pumpAndSettle();
    expect(cubit.state.tasksFor(done).map((task) => task.id), ['2']);
    await cubit.load('p', refresh: true);
    expect(cubit.state.epicFilterIds, {'active', 'done'});
    cubit.setSearch('Подготовка');
    expect(cubit.state.tasksFor(done), isEmpty);
    cubit.setSearch('');
    await tester.tap(find.byKey(const Key('epics-clear-selection')));
    await tester.pumpAndSettle();
    expect(cubit.state.epicFilterIds, isEmpty);
    expect(cubit.state.tasksFor(todo), hasLength(1));
    expect(cubit.state.tasksFor(done), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a colored epic, validates name and refreshes list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: ProjectEpicsScreen(projectId: 'p')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('epics-add')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('epic-create-submit')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('epic-name')),
      '  Новый эпик  ',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('#2563EB'));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('epic-create-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.createdProject, 'p');
    expect(repository.created.single.name, 'Новый эпик');
    expect(repository.created.single.color, '#2563EB');
    expect(find.text('Новый эпик'), findsOneWidget);
    expect(find.byKey(const Key('epic-name')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creation error preserves form for retry and cancel closes it', (
    tester,
  ) async {
    repository.failCreate = true;
    await tester.pumpWidget(
      const MaterialApp(home: ProjectEpicsScreen(projectId: 'p')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('epics-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('epic-name')), 'Повтор');
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('epic-create-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось создать эпик.'), findsOneWidget);
    expect(find.text('Повтор'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('epic-create-cancel')));
    await tester.tap(find.byKey(const Key('epic-create-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('epic-name')), findsNothing);
    expect(repository.created, isEmpty);
  });

  testWidgets('search and task filters work on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: ProjectEpicsScreen(projectId: 'p')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Запуск'), findsOneWidget);
    expect(find.text('Идеи'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('epics-filter-empty')),
    );
    await tester.tap(find.byKey(const ValueKey('epics-filter-empty')));
    await tester.pumpAndSettle();
    expect(find.text('Идеи'), findsOneWidget);
    expect(find.text('Запуск'), findsNothing);
    final completed = find.byKey(const ValueKey('epics-filter-completed'));
    await tester.ensureVisible(completed);
    await tester.tap(completed);
    await tester.pumpAndSettle();
    expect(find.text('Релиз'), findsOneWidget);
    expect(find.text('Идеи'), findsNothing);
    await tester.tap(find.text('Релиз'));
    await tester.pumpAndSettle();
    expect(find.text('Готово'), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('epic-filter-done')))
          .value,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('epics-search')),
      'нет совпадений',
    );
    await tester.pumpAndSettle();
    expect(find.text('По выбранным фильтрам эпиков нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure can be retried', (tester) async {
    repository.fail = true;
    await tester.pumpWidget(
      const MaterialApp(home: ProjectEpicsScreen(projectId: 'p')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить эпики'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Запуск'), findsOneWidget);
  });
}

class _BoardRepository implements KanbanRepository {
  _BoardRepository(this.repository);
  final _Repository repository;

  @override
  void cancelPendingLoads() {}

  @override
  Future<KanbanBoardData> loadBoard(
    String projectId, {
    String? search,
    int take = 100,
    int skip = 0,
  }) async => KanbanBoardData(
    columns: const [
      KanbanColumnModel(id: 'todo', name: 'К работе', statusMap: 'TODO'),
      KanbanColumnModel(id: 'done', name: 'Готово', statusMap: 'DONE'),
    ],
    tasks: await repository.getTasksForProjectIds([projectId]),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
