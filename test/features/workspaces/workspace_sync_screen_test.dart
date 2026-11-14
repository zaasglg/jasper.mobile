import 'package:jospar/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/projects/data/models/create_project_request.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_state.dart';
import 'package:jospar/features/shell/presentation/widgets/app_drawer.dart';
import 'package:jospar/features/shell/presentation/screens/main_shell.dart';
import 'package:jospar/features/workspaces/data/models/create_workspace_request.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

class _Workspaces implements WorkspaceRepository {
  int loads = 0;
  List<WorkspaceModel> workspaces = [
    const WorkspaceModel(id: 'one', name: 'Старое имя'),
  ];
  @override
  Future<List<WorkspaceModel>> getWorkspaces() async {
    loads++;
    return workspaces;
  }

  @override
  Future<List<WorkspaceModel>> getArchivedWorkspaces() async => [
    const WorkspaceModel(id: 'archive', name: 'Архив с сайта'),
  ];
  @override
  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request) =>
      throw UnimplementedError();
}

class _Projects implements ProjectRepository {
  List<ProjectModel> projects = [];

  @override
  Future<List<ProjectModel>> getProjects() async => projects;
  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('left-edge swipe navigates back instead of opening the drawer', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    sl.registerFactory<WorkspaceCubit>(
      () => WorkspaceCubit(
        repository: _Workspaces(),
        selectionStorage: WorkspaceSelectionStorage(
          const FlutterSecureStorage(),
        ),
      ),
    );
    sl.registerFactory<ProjectsCubit>(() => ProjectsCubit(_Projects()));
    addTearDown(() async {
      await sl.unregister<WorkspaceCubit>();
      await sl.unregister<ProjectsCubit>();
    });
    final router = GoRouter(
      initialLocation: '/projects',
      routes: [
        ShellRoute(
          builder: (_, _, child) =>
              MainShell(currentIndex: 1, onTap: (_) {}, child: child),
          routes: [
            GoRoute(
              path: '/projects',
              builder: (context, _) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: MainShell.openDrawer,
                      child: const Text('Меню'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/projects/one'),
                      child: const Text('Открыть проект'),
                    ),
                  ],
                ),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, _) => const Scaffold(
                    body: Center(child: Text('Детали проекта')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(platform: TargetPlatform.iOS),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    Future<void> swipeBack() async {
      await tester.timedDragFrom(
        const Offset(2, 300),
        const Offset(320, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
    }

    await swipeBack();
    expect(MainShell.scaffoldKey.currentState!.isDrawerOpen, isFalse);
    expect(router.routeInformationProvider.value.uri.path, '/projects');
    await tester.tap(find.text('Открыть проект'));
    await tester.pumpAndSettle();
    expect(find.text('Детали проекта'), findsOneWidget);
    await tester.timedDragFrom(
      const Offset(2, 300),
      const Offset(35, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Детали проекта'), findsOneWidget);
    await swipeBack();
    expect(router.routeInformationProvider.value.uri.path, '/projects');
    expect(find.text('Детали проекта'), findsNothing);
    expect(find.text('Открыть проект'), findsOneWidget);
    expect(MainShell.scaffoldKey.currentState!.isDrawerOpen, isFalse);
    await tester.tap(find.text('Меню'));
    await tester.pumpAndSettle();
    expect(MainShell.scaffoldKey.currentState!.isDrawerOpen, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selecting workspace from drawer reloads projects and leaves old details',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final selectionStorage = WorkspaceSelectionStorage(storage);
      final repository = _Workspaces()
        ..workspaces = const [
          WorkspaceModel(id: 'one', name: 'Цифровизация'),
          WorkspaceModel(id: 'two', name: 'Продажи'),
        ];
      final projectRepository = _Projects()
        ..projects = const [
          ProjectModel(
            id: 'old',
            code: 'OLD',
            name: 'Прежний проект',
            workspaceId: 'one',
            start: null,
            end: null,
          ),
          ProjectModel(
            id: 'new',
            code: 'NEW',
            name: 'Проект продаж',
            workspaceId: 'two',
            start: null,
            end: null,
          ),
        ];
      final workspace = WorkspaceCubit(
        repository: repository,
        selectionStorage: selectionStorage,
      );
      final projects = ProjectsCubit(projectRepository);
      sl.registerFactory<WorkspaceCubit>(() => workspace);
      sl.registerFactory<ProjectsCubit>(() => projects);
      addTearDown(() async {
        await sl.unregister<WorkspaceCubit>();
        await sl.unregister<ProjectsCubit>();
      });
      final router = GoRouter(
        initialLocation: '/projects/old',
        routes: [
          ShellRoute(
            builder: (_, _, child) =>
                MainShell(currentIndex: 1, onTap: (_) {}, child: child),
            routes: [
              GoRoute(
                path: '/projects',
                builder: (_, _) => BlocBuilder<ProjectsCubit, ProjectsState>(
                  builder: (_, state) => Column(
                    children: [
                      for (final project in state.projects) Text(project.name),
                    ],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, _) => const Text('Детали прежнего проекта'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(projects.state.workspaceId, 'one');

      MainShell.openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('Цифровизация'), findsOneWidget);
      expect(find.text('Продажи'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDrawer),
          matching: find.text('Прежний проект'),
        ),
        findsNothing,
      );
      final selectedWorkspace = find.byKey(const Key('drawer-workspace-one'));
      expect(
        tester
            .widget<Semantics>(
              find
                  .descendant(
                    of: selectedWorkspace,
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Продажи'));
      await tester.pumpAndSettle();

      expect((workspace.state as WorkspaceLoaded).selected?.id, 'two');
      expect(await selectionStorage.read(), 'two');
      expect(projects.state.workspaceId, 'two');
      expect(projects.state.projects.single.id, 'new');
      expect(router.routeInformationProvider.value.uri.path, '/projects');
      expect(MainShell.scaffoldKey.currentState!.isDrawerOpen, isFalse);
      expect(find.text('Проект продаж'), findsOneWidget);
      expect(find.text('Детали прежнего проекта'), findsNothing);

      MainShell.openDrawer();
      await tester.pumpAndSettle();
      final salesWorkspace = find.byKey(const Key('drawer-workspace-two'));
      expect(
        tester
            .widget<Semantics>(
              find
                  .descendant(
                    of: salesWorkspace,
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .selected,
        isTrue,
      );
      expect(find.text('Настройки'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'drawer refreshes server data, polls only in foreground, and loads archive',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      FlutterSecureStorage.setMockInitialValues({});
      final repository = _Workspaces();
      sl.registerFactory<WorkspaceCubit>(
        () => WorkspaceCubit(
          repository: repository,
          selectionStorage: WorkspaceSelectionStorage(
            const FlutterSecureStorage(),
          ),
        ),
      );
      sl.registerFactory<ProjectsCubit>(() => ProjectsCubit(_Projects()));
      addTearDown(() async {
        await sl.unregister<WorkspaceCubit>();
        await sl.unregister<ProjectsCubit>();
      });
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, state) {
              final args = state.extra! as SettingsNavigationData;
              return SettingsScreen(
                voiceController: args.voice,
                workspaceCubit: args.workspace,
              );
            },
          ),
          GoRoute(
            path: '/manage/workspaces/:id',
            builder: (context, state) => Scaffold(
              body: TextButton(
                child: Text('Изменить workspace ${state.pathParameters['id']}'),
                onPressed: () {
                  repository.workspaces = [
                    const WorkspaceModel(
                      id: 'one',
                      name: 'Новое имя из настроек',
                    ),
                  ];
                  context.pop();
                },
              ),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => MainShell(
              currentIndex: 0,
              onTap: (_) {},
              child: const Text('Экран'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(repository.loads, 1);
      repository.workspaces = [
        const WorkspaceModel(id: 'one', name: 'Новое имя с сайта'),
      ];
      MainShell.openDrawer();
      await tester.pumpAndSettle();
      expect(repository.loads, 2);
      expect(find.text('Новое имя с сайта'), findsOneWidget);
      await tester.tap(find.text('Архивированные'));
      await tester.pumpAndSettle();
      expect(find.text('Архив с сайта'), findsOneWidget);
      repository.workspaces = [
        const WorkspaceModel(id: 'one', name: 'Обновлено снова'),
      ];
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(repository.loads, 3);
      expect(find.text('Обновлено снова'), findsWidgets);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(repository.loads, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repository.loads, 4);
      MainShell.scaffoldKey.currentState!.closeDrawer();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 60));
      expect(repository.loads, 4);
      MainShell.openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('Workspace'), findsNothing);
      expect(find.byTooltip('Архив workspace'), findsNothing);
      expect(find.text('Архивированные'), findsOneWidget);
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      final workspaceSettings = find.byKey(const Key('settings-workspace'));
      await tester.ensureVisible(workspaceSettings);
      expect(find.text('Настройки workspace'), findsOneWidget);
      await tester.tap(workspaceSettings);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить workspace one'));
      await tester.pumpAndSettle();
      expect(find.text('Новое имя из настроек'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
