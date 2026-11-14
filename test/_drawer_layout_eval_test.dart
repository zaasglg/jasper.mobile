import 'package:go_router/go_router.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
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
  const previewFont = String.fromEnvironment('DRAWER_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isEmpty) return;
    final bytes = ByteData.sublistView(await File(previewFont).readAsBytes());
    for (final family in [
      'Roboto',
      'Manrope',
      'Manrope_regular',
      'Manrope_500',
      'Manrope_600',
      'Manrope_700',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

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

      final captureKey = GlobalKey();
      Future<void> capture(String name) async {
        if (previewFont.isEmpty) return;
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('/tmp/jospar-drawer-ui');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final scaffoldKey = GlobalKey<ScaffoldState>();
      final router = GoRouter(
        initialLocation: '/projects/test',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (context, state) => Scaffold(
              key: scaffoldKey,
              drawer: AppDrawer(onOpenSettings: () {}),
              body: const SizedBox.expand(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<WorkspaceCubit>.value(value: workspaceCubit),
          ],
          child: RepaintBoundary(
            key: captureKey,
            child: MaterialApp.router(
              theme: AppTheme.light,
              debugShowCheckedModeBanner: false,
              routerConfig: router,
            ),
          ),
        ),
      );
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      final settingsPosition = tester.getCenter(find.text('Настройки'));
      expect(find.text('Проекты'), findsNothing);
      expect(find.text('Тестовый проект'), findsNothing);
      expect(find.text('Архивированные воркспейсы'), findsOneWidget);
      expect(find.text('Создать Workspace'), findsNothing);
      await capture('collapsed-375x480');
      await tester.tap(find.byKey(const Key('drawer-workspace-switcher')));
      await tester.pumpAndSettle();
      expect(find.text('Проекты'), findsNothing);
      expect(find.text('Цифровизация'), findsNWidgets(2));
      await capture('expanded-375x480');
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
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('drawer-scroll-view')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      await capture('expanded-390x844');
      await tester.tap(find.byKey(const Key('drawer-workspace-switcher')));
      await tester.pumpAndSettle();
      await capture('collapsed-390x844');
      expect(find.text('Проекты'), findsNothing);
      await tester.tap(find.text('Архивированные воркспейсы'));
      await tester.pumpAndSettle();
      expect(find.text('Нет архивированных workspace'), findsOneWidget);
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
