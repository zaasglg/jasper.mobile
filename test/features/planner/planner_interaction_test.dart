import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/kanban/presentation/widgets/task_card.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';

void main() {
  testWidgets('task menu schedules the original project task', (tester) async {
    final repository = _Repository();
    sl.registerFactory<PlannerCubit>(() => PlannerCubit(repository));
    addTearDown(() => sl.unregister<PlannerCubit>());
    final workspace = _WorkspaceCubit();
    addTearDown(workspace.close);
    await tester.pumpWidget(
      BlocProvider<WorkspaceCubit>.value(
        value: workspace,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: ProjectTaskModel(
                id: 'original-task',
                projectId: 'original-project',
                title: 'Задача проекта',
                status: 'TODO',
                order: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('task-actions-original-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В ежедневник'));
    await tester.pumpAndSettle();
    expect(find.text('Добавить в ежедневник'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.addedTaskId, 'original-task');
    expect(repository.addedProjectId, 'original-project');
    expect(repository.createdTitle, isNull);
    expect(find.text('Задача добавлена в ежедневник'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling down refreshes day, week and month views', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = PlannerCubit(repository);
    addTearDown(cubit.close);
    await cubit.configure('workspace');
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Обновить'), findsNothing);

    for (final mode in ['День', 'Неделя', 'Месяц']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('planner-pull-to-refresh')),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      final previousLoads = repository.loadCount;
      await tester.drag(scrollable, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(repository.loadCount, previousLoads + 1, reason: mode);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'renders overlapping tasks and supports completion, creation and calendar views on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final cubit = PlannerCubit(repository);
      addTearDown(cubit.close);
      await cubit.configure('workspace');
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(home: const PlannerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Подготовить презентацию'), findsOneWidget);
      expect(find.text('Проверить бюджет'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('planner-complete-first')));
      await tester.pumpAndSettle();
      expect(cubit.state.items.first.completed, isTrue);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Подготовить презентацию')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('planner-hour-11'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(plannerLocal(repository.lastScheduledAt!).hour, 11);
      await tester.tap(find.byKey(const Key('planner-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Новая задача');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repository.createdTitle, 'Новая задача');
      await tester.tap(find.text('Неделя'));
      await tester.pumpAndSettle();
      expect(find.text('Пн'), findsOneWidget);
      await tester.tap(find.text('Месяц'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late-night items fit the timeline without layout exceptions', (
    tester,
  ) async {
    final repository = _Repository(late: true);
    final cubit = PlannerCubit(repository);
    addTearDown(cubit.close);
    await cubit.configure('workspace');
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements PlannerRepository {
  _Repository({this.late = false});
  final bool late;
  int loadCount = 0;
  String? createdTitle;
  String? addedTaskId;
  String? addedProjectId;
  DateTime? lastScheduledAt;
  List<PlannerItemModel> get items => [
    PlannerItemModel(
      id: 'first',
      title: 'Подготовить презентацию',
      scheduledAt: plannerInstant(plannerNow(), late ? 23 : 9, late ? 59 : 0),
      durationMinutes: 90,
    ),
    if (!late)
      PlannerItemModel(
        id: 'second',
        title: 'Проверить бюджет',
        scheduledAt: plannerInstant(plannerNow(), 9, 30),
        durationMinutes: 60,
      ),
  ];
  @override
  Future<List<PlannerItemModel>> load(String workspaceId) async {
    loadCount++;
    return items;
  }

  @override
  Future<void> update(
    PlannerItemModel item, {
    String? title,
    DateTime? scheduledAt,
    int? durationMinutes,
    bool? completed,
  }) async {
    lastScheduledAt = scheduledAt ?? lastScheduledAt;
  }

  @override
  Future<PlannerItemModel> create(
    String workspaceId, {
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    createdTitle = title;
    return PlannerItemModel(
      id: 'new',
      title: title,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
    );
  }

  @override
  Future<void> remove(String itemId) async {}
  @override
  Future<void> addTask(
    String workspaceId, {
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    addedTaskId = taskId;
    addedProjectId = projectId;
  }
}

class _WorkspaceCubit extends Cubit<WorkspaceState> implements WorkspaceCubit {
  _WorkspaceCubit()
    : super(
        const WorkspaceLoaded(
          workspaces: [WorkspaceModel(id: 'workspace', name: 'Команда')],
          selected: WorkspaceModel(id: 'workspace', name: 'Команда'),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
