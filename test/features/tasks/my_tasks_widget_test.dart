import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_collapsible_widget.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:jospar/features/projects/domain/entities/task_epic_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/domain/entities/kanban_column_model.dart';
import 'package:jospar/features/tasks/domain/entities/task_extra_field.dart';
import 'package:jospar/features/tasks/domain/repositories/my_task_fields_storage.dart';
import 'package:jospar/features/tasks/domain/repositories/my_tasks_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:jospar/features/tasks/presentation/widgets/my_tasks_widget.dart';

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('mobile task rows fit text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cubit = MyTasksCubit(
        repository: const _Repository(),
        fieldsStorage: _Storage(),
      );
      await cubit.configure(
        userId: 'user',
        projects: const <ProjectModel>[
          ProjectModel(
            id: 'project',
            code: 'ORB',
            name: 'Orbita Platform Backend',
            workspaceId: 'workspace',
            start: null,
            end: null,
          ),
        ],
      );
      addTearDown(cubit.close);
      final planner = _PlannerRepository();
      sl.registerFactory<PlannerCubit>(() => PlannerCubit(planner));
      addTearDown(() => sl.reset());

      await tester.pumpWidget(
        BlocProvider<MyTasksCubit>.value(
          value: cubit,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: MyTasksWidget()),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('my-tasks-widget')), findsOneWidget);
      expect(find.text('Мои задачи'), findsOneWidget);
      expect(find.text('ORB-12'), findsOneWidget);
      expect(find.text('Подготовить мобильный релиз'), findsOneWidget);
      expect(find.text('К работе'), findsOneWidget);
      expect(find.text('Мобильное приложение'), findsOneWidget);
      expect(find.textContaining('Колонка ·'), findsNothing);
      expect(find.textContaining('Эпики ·'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        BlocProvider<MyTasksCubit>.value(
          value: cubit,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: DashboardCollapsibleWidget(
                  title: 'Мои задачи',
                  icon: Icons.checklist,
                  child: MyTasksWidget(expandContent: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.getRect(
        find.byKey(const Key('dashboard_widget_heading_surface')),
      );
      final fields = tester.getRect(
        find.byKey(const Key('my-tasks-fields-button')),
      );
      expect(fields.top - header.bottom, inInclusiveRange(0, 8));
      expect(find.text('Мои задачи'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('my-tasks-fields-button')));
      await tester.pumpAndSettle();
      expect(find.text('Показывать в списке'), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('Колонка'), findsOneWidget);
      expect(find.text('Эпики'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Показывать в списке'))).pop();
      await tester.pumpAndSettle();
      final schedule = find.byKey(const ValueKey('my-task-schedule-task'));
      await tester.ensureVisible(schedule);
      await tester.tap(schedule);
      await tester.pumpAndSettle();
      expect(find.text('Добавить в ежедневник'), findsOneWidget);
      expect(find.text('Подготовить мобильный релиз'), findsWidgets);
      await tester.tap(find.byKey(const Key('schedule-confirm')));
      await tester.pumpAndSettle();
      expect(planner.taskId, 'task');
      expect(planner.projectId, 'project');
      expect(planner.plannedDate, isNotNull);
      expect(planner.scheduledAt, isNull);
      expect(find.text('Задача добавлена в ежедневник'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Repository implements MyTasksRepository {
  const _Repository();

  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const <String>[],
  }) async {
    return <ProjectTaskModel>[
      ProjectTaskModel(
        id: 'task',
        displayId: 'ORB-12',
        title: 'Подготовить мобильный релиз',
        projectId: 'project',
        status: 'TODO',
        end: DateTime(2026, 9, 8),
        epics: const <TaskEpicModel>[
          TaskEpicModel(id: 'epic', name: 'Мобильное приложение'),
        ],
      ),
    ];
  }

  @override
  Future<List<KanbanColumnModel>> getKanbanColumns(String projectId) async {
    return const <KanbanColumnModel>[
      KanbanColumnModel(id: 'todo', name: 'К работе', statusMap: 'TODO'),
    ];
  }

  @override
  Future<void> updateProgress(
    String taskId,
    int progress, {
    String? status,
  }) async {}
}

class _Storage implements MyTaskFieldsStorage {
  @override
  Future<Set<TaskExtraField>> read() async => TaskExtraField.values.toSet();

  @override
  Future<void> save(Set<TaskExtraField> fields) async {}
}

class _PlannerRepository implements PlannerRepository {
  @override
  Future<void> updateExtras(String itemId, {bool updateIcon = false, String? icon, List<TaskChecklistModel>? checklists}) async {}

  String? taskId, projectId;
  DateTime? plannedDate, scheduledAt;
  @override
  Future<List<PlannerItemModel>> load() async => [];
  @override
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) async {
    this.taskId = taskId;
    this.projectId = projectId;
    this.plannedDate = plannedDate;
    this.scheduledAt = scheduledAt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
