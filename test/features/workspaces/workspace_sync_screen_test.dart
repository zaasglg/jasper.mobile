import 'package:jospar/features/shell/presentation/widgets/app_bottom_navigation.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/entities/create_project_request.dart';
import 'package:jospar/features/profile/presentation/widgets/profile_settings_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_state.dart';
import 'package:jospar/features/workspaces/presentation/widgets/workspace_switcher.dart';
import 'package:jospar/features/shell/presentation/screens/main_shell.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
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
  Future<WorkspaceModel> createWorkspace(
    CreateWorkspaceRequest request,
  ) async => WorkspaceModel(id: 'created', name: request.name);
}

class _Projects implements ProjectRepository {
  @override
  Future<void> setPinned(String id, bool pinned) async {}
  @override
  Future<void> archiveProject(String id) async {}

  @override
  Future<void> moveProject(
    String id, {
    required String workspaceId,
    String? parentId,
    String? anchorId,
    required String placement,
  }) async {}

  int loads = 0;
  List<ProjectModel> projects = [];

  @override
  Future<List<ProjectModel>> getProjects() async {
    loads++;
    return projects;
  }

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) =>
      throw UnimplementedError();
}

void main() {
  testWidgets(
    'new account never builds workspace tabs before creating a workspace',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      FlutterSecureStorage.setMockInitialValues({
        'selected_workspace_id': 'stale',
      });
      final repository = _Workspaces()..workspaces = [];
      final projects = _Projects();
      sl.registerFactory<WorkspaceCubit>(
        () => WorkspaceCubit(
          repository: repository,
          selectionStorage: const WorkspaceSelectionStorage(
            FlutterSecureStorage(),
          ),
        ),
      );
      sl.registerFactory<ProjectsCubit>(() => ProjectsCubit(projects));
      addTearDown(() async {
        await sl.unregister<WorkspaceCubit>();
        await sl.unregister<ProjectsCubit>();
      });
      var tabBuilds = 0;
      final router = GoRouter(
        routes: [
          ShellRoute(
            builder: (_, _, child) =>
                MainShell(currentIndex: 0, onTap: (_) {}, child: child),
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Builder(
                  builder: (_) {
                    tabBuilds++;
                    return const Text('Workspace data');
                  },
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Создайте первое пространство'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsNothing);
      expect(tabBuilds, 0);
      expect(projects.loads, 0);
      expect(
        await const FlutterSecureStorage().read(key: 'selected_workspace_id'),
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('first-workspace-name')),
        'Личное',
      );
      await tester.ensureVisible(
        find.byKey(const Key('first-workspace-create')),
      );
      await tester.tap(find.byKey(const Key('first-workspace-create')));
      await tester.pumpAndSettle();
      expect(find.text('Workspace data'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(projects.loads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

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
                    const WorkspaceSwitcher(),
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
    expect(find.byType(Drawer), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selecting workspace from Forui switcher reloads projects and leaves old details',
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
                      const WorkspaceSwitcher(),
                      for (final project in state.projects) Text(project.name),
                    ],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, _) => const Column(
                      children: [
                        WorkspaceSwitcher(),
                        Text('Детали прежнего проекта'),
                      ],
                    ),
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

      await tester.tap(find.byKey(const Key('workspace-switcher')));
      await tester.pumpAndSettle();
      expect(find.text('Продажи'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
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

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Forui switcher creates and selects a workspace', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    final storage = WorkspaceSelectionStorage(const FlutterSecureStorage());
    final cubit = WorkspaceCubit(
      repository: _Workspaces(),
      selectionStorage: storage,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(body: SafeArea(child: WorkspaceSwitcher())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Команда');
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();
    expect((cubit.state as WorkspaceLoaded).selected?.name, 'Команда');
    expect(await storage.read(), 'created');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace switcher refreshes server data and opens archive', (
    tester,
  ) async {
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
          path: '/profile',
          builder: (_, state) {
            final args = state.extra! as ProfileNavigationData;
            return Scaffold(
              body: SingleChildScrollView(
                child: ProfileSettingsSections(
                  voiceController: args.voice,
                  workspaceCubit: args.workspace,
                ),
              ),
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
            child: const WorkspaceSwitcher(),
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
    await tester.tap(find.byKey(const Key('workspace-switcher')));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(find.text('Новое имя с сайта'), findsWidgets);
    await tester.tap(find.text('Архивированные'));
    await tester.pumpAndSettle();
    expect(find.text('Архив с сайта'), findsOneWidget);
    repository.workspaces = [
      const WorkspaceModel(id: 'one', name: 'Обновлено снова'),
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 60));
    expect(repository.loads, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.loads, 3);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Обновлено снова'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
