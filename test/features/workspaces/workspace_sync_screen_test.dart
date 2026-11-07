import 'package:jospar/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
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
import 'package:jospar/features/shell/presentation/screens/main_shell.dart';
import 'package:jospar/features/workspaces/data/models/create_workspace_request.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';

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
  @override
  Future<List<ProjectModel>> getProjects() async => [];
  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) =>
      throw UnimplementedError();
}

void main() {
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
      await tester.tap(find.text('Новое имя с сайта'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Обновлено снова').first);
      await tester.pumpAndSettle();
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
