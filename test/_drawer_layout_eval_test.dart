import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/projects/data/models/create_project_request.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/shell/presentation/widgets/app_drawer.dart';
import 'package:jospar/features/workspaces/data/models/create_workspace_request.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'short drawer keeps workspace form and projects in one scroll',
    (tester) async {
      final bytes = await File('/tmp/jospar-manrope.ttf').readAsBytes();
      await (FontLoader(
        'Manrope',
      )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
      GoogleFonts.config.allowRuntimeFetching = false;
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final workspaceCubit = WorkspaceCubit(
        repository: _WorkspaceRepo(),
        selectionStorage: WorkspaceSelectionStorage(
          const FlutterSecureStorage(),
        ),
      );
      final projectsCubit = ProjectsCubit(_ProjectRepo());
      await workspaceCubit.load();
      await projectsCubit.loadForWorkspace('ws-digital');
      addTearDown(workspaceCubit.close);
      addTearDown(projectsCubit.close);

      final scaffoldKey = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<WorkspaceCubit>.value(value: workspaceCubit),
            BlocProvider<ProjectsCubit>.value(value: projectsCubit),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: AppDrawer(onCreateProject: () async {}),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      scaffoldKey.currentState!.openDrawer();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Цифровизация').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byKey(const Key('add-workspace-row')));
      await tester.tap(find.byKey(const Key('add-workspace-row')));
      await tester.pump(const Duration(milliseconds: 300));

      final createButton = find.byKey(const Key('create-workspace-button'));
      final cancelButton = find.byKey(const Key('cancel-workspace-button'));
      final projectsContent = find.byKey(const Key('drawer-projects-content'));
      final projectPlus = find.byKey(const Key('create-project-button'));
      expect(createButton, findsOneWidget);
      expect(cancelButton, findsOneWidget);
      expect(projectsContent, findsOneWidget);
      expect(
        tester.getBottomLeft(cancelButton).dy,
        lessThanOrEqualTo(tester.getTopLeft(projectsContent).dy),
      );

      await tester.ensureVisible(cancelButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(cancelButton, findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drawer_form_reachable.png'),
      );

      await tester.ensureVisible(projectPlus);
      await tester.pump(const Duration(milliseconds: 300));
      expect(projectPlus, findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drawer_projects_reachable.png'),
      );
    },
    // This manual golden evaluation needs a font fixture outside the repo.
    skip: !File('/tmp/jospar-manrope.ttf').existsSync(),
  );
}

class _WorkspaceRepo implements WorkspaceRepository {
  @override
  Future<List<WorkspaceModel>> getWorkspaces() async => const <WorkspaceModel>[
    WorkspaceModel(id: 'ws-digital', name: 'Цифровизация', color: '#6D5FE0'),
    WorkspaceModel(
      id: 'ws-management',
      name: 'Проектное управление',
      color: '#3DABC3',
    ),
    WorkspaceModel(id: 'ws-sales', name: 'Продажи', color: '#3CAF78'),
    WorkspaceModel(id: 'ws-support', name: 'Поддержка', color: '#3B82C4'),
    WorkspaceModel(id: 'ws-green', name: 'гринпис', color: '#6D5FE0'),
    WorkspaceModel(id: 'ws-a', name: 'автвлоа', color: '#6D5FE0'),
    WorkspaceModel(id: 'ws-b', name: 'asdas', color: '#6D5FE0'),
    WorkspaceModel(id: 'ws-c', name: 'asds', color: '#6D5FE0'),
  ];

  @override
  Future<WorkspaceModel> createWorkspace(
    CreateWorkspaceRequest request,
  ) async =>
      WorkspaceModel(id: 'created', name: request.name, color: request.color);
}

class _ProjectRepo implements ProjectRepository {
  @override
  Future<List<ProjectModel>> getProjects() async => <ProjectModel>[
    ProjectModel(
      id: 'pinned',
      code: 'PIN',
      name: 'Процессы отдела продаж',
      workspaceId: 'ws-digital',
      start: null,
      end: null,
      isPinned: true,
    ),
    ProjectModel(
      id: 'project',
      code: 'ORB',
      name: 'Orbita Platform',
      workspaceId: 'ws-digital',
      start: null,
      end: null,
    ),
  ];

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) =>
      throw UnimplementedError();
}
