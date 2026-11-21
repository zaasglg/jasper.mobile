import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_layout.dart';
import 'package:jospar/features/dashboard/presentation/cubit/dashboard_layout_cubit.dart';
import 'package:jospar/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/inbox/presentation/cubit/inbox_cubit.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/tasks/domain/entities/task_extra_field.dart';
import 'package:jospar/features/tasks/domain/repositories/my_task_fields_storage.dart';
import 'package:jospar/features/tasks/domain/repositories/my_tasks_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:jospar/features/tasks/domain/entities/kanban_column_model.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';
import 'dashboard_layout_test.dart' show FakeDashboardRepository;

void main() {
  testWidgets(
    'header buttons edit shared dashboard, add, cancel and save on a narrow phone',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeDashboardRepository();
      repo.value = DashboardLayout.defaults().copyWith(
        widgets: DashboardLayout.defaults().widgets
            .map((e) => e.copyWith(visible: false))
            .toList(),
      );
      final cubit = DashboardLayoutCubit(repo);
      sl.registerFactory<DashboardLayoutCubit>(() => cubit);
      sl.registerFactory<ProfileCubit>(() => ProfileCubit(_Profile()));
      sl.registerFactory<MyTasksCubit>(
        () => MyTasksCubit(repository: _Tasks(), fieldsStorage: _Fields()),
      );
      sl.registerFactory<InboxCubit>(() => InboxCubit(_Inbox()));
      addTearDown(() => sl.reset());
      final projects = ProjectsCubit(_Projects());
      await projects.loadForWorkspace('w');
      addTearDown(projects.close);
      final workspace = _Workspace();
      addTearDown(workspace.close);
      String? requestedWorkspace;
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider<ProjectsCubit>.value(value: projects),
                BlocProvider<WorkspaceCubit>.value(value: workspace),
              ],
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/tasks/new',
            builder: (_, state) {
              requestedWorkspace = state.uri.queryParameters['workspaceId'];
              return const Scaffold(body: Text('Форма создания задачи'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Цифровизация'), findsOneWidget);
      expect(find.text('Дашборд'), findsNothing);
      workspace.showWorkspace(
        const WorkspaceModel(
          id: 'w',
          name: 'Цифровизация и развитие рабочих процессов',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Цифровизация'), findsNothing);
      expect(
        find.text('Цифровизация и развитие рабочих процессов'),
        findsOneWidget,
      );
      expect(
        find.text('Добавьте виджеты через кнопку редактирования'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Редактировать виджеты'));
      await tester.pumpAndSettle();
      expect(find.text('Редактирование виджетов'), findsOneWidget);
      await tester.tap(find.text('Добавить виджет'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Скрам'));
      await tester.pumpAndSettle();
      expect(
        cubit.state.current!.widgets
            .firstWhere((e) => e.id == 'tasks-summary')
            .visible,
        true,
      );
      expect(repo.saved, isEmpty);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(cubit.state.layout!.widgets.every((e) => !e.visible), true);
      await tester.tap(find.byTooltip('Редактировать виджеты'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить виджет'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Скрам'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repo.saved.length, 1);
      expect(repo.saved.single.$1, 'w');
      expect(
        repo.saved.single.$2.widgets
            .firstWhere((e) => e.id == 'tasks-summary')
            .visible,
        true,
      );
      expect(find.text('Редактирование виджетов'), findsNothing);
      await tester.tap(find.byTooltip('Добавить задачу'));
      await tester.pumpAndSettle();
      expect(find.text('Форма создания задачи'), findsOneWidget);
      expect(requestedWorkspace, 'w');
      expect(cubit.state.editing, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Workspace extends Cubit<WorkspaceState> implements WorkspaceCubit {
  _Workspace() : super(const WorkspaceInitial()) {
    showWorkspace(const WorkspaceModel(id: 'w', name: 'Цифровизация'));
  }

  void showWorkspace(WorkspaceModel workspace) =>
      emit(WorkspaceLoaded(workspaces: [workspace], selected: workspace));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async =>
      const UserProfile(id: 'u', name: 'Алия', email: 'aliya@example.kz');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Projects implements ProjectRepository {
  @override
  Future<List<ProjectModel>> getProjects() async => const [
    ProjectModel(
      id: 'p',
      code: 'PR',
      name: 'Проект 12',
      workspaceId: 'w',
      start: null,
      end: null,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tasks implements MyTasksRepository {
  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const [],
  }) async => [];
  @override
  Future<List<KanbanColumnModel>> getKanbanColumns(String projectId) async =>
      [];
  @override
  Future<void> updateProgress(
    String taskId,
    int progress, {
    String? status,
  }) async {}
}

class _Fields implements MyTaskFieldsStorage {
  @override
  Future<Set<TaskExtraField>> read() async => {};
  @override
  Future<void> save(Set<TaskExtraField> fields) async {}
}

class _Inbox implements InboxRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
