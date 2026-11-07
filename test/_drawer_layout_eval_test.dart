import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/shell/presentation/widgets/app_drawer.dart';
import 'package:jospar/features/workspaces/data/models/create_workspace_request.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'short drawer scrolls workspaces and form with settings fixed below',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      tester.view.physicalSize = const Size(375, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final workspaceCubit = WorkspaceCubit(
        repository: _WorkspaceRepo(),
        selectionStorage: WorkspaceSelectionStorage(
          const FlutterSecureStorage(),
        ),
      );
      await workspaceCubit.load();
      addTearDown(workspaceCubit.close);

      final scaffoldKey = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<WorkspaceCubit>.value(value: workspaceCubit),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: AppDrawer(onOpenSettings: () {}),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      final settingsPosition = tester.getCenter(find.text('Настройки'));
      expect(find.text('ВОРКСПЕЙСЫ'), findsOneWidget);
      expect(find.text('Цифровизация'), findsOneWidget);
      expect(find.text('ПРОЕКТЫ'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('add-workspace-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-workspace-row')));
      await tester.pump(const Duration(milliseconds: 300));

      final createButton = find.byKey(const Key('create-workspace-button'));
      final cancelButton = find.byKey(const Key('cancel-workspace-button'));
      final workspacesContent = find.byKey(
        const Key('drawer-workspaces-content'),
      );
      expect(createButton, findsOneWidget);
      expect(cancelButton, findsOneWidget);
      expect(workspacesContent, findsOneWidget);

      await tester.ensureVisible(cancelButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(cancelButton, findsOneWidget);
      expect(tester.getCenter(find.text('Настройки')), settingsPosition);
      expect(tester.takeException(), isNull);
    },
  );
}

class _WorkspaceRepo implements WorkspaceRepository {
  @override
  Future<List<WorkspaceModel>> getArchivedWorkspaces() async => [];

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
