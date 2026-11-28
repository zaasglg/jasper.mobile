import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';
import 'package:jospar/features/workspaces/presentation/widgets/workspace_switcher.dart';

class _Repository implements WorkspaceRepository {
  _Repository([
    this.items = const [
      WorkspaceModel(id: 'a', name: 'Первый'),
      WorkspaceModel(id: 'b', name: 'Второй'),
      WorkspaceModel(id: 'c', name: 'Третий'),
    ],
  ]);

  final List<WorkspaceModel> items;

  @override
  Future<List<WorkspaceModel>> getWorkspaces() async => items;
  @override
  Future<List<WorkspaceModel>> getArchivedWorkspaces() async => [];
  @override
  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request) =>
      throw UnimplementedError();
}

void main() {
  testWidgets(
    'menu stays open, all checks every row and individual toggle removes a check',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      FlutterSecureStorage.setMockInitialValues({});
      final cubit = WorkspaceCubit(
        repository: _Repository(),
        selectionStorage: const WorkspaceSelectionStorage(
          FlutterSecureStorage(),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: WorkspaceSwitcher()),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.byKey(const Key('workspace-switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Второй'));
      await tester.pumpAndSettle();
      expect(find.text('Третий'), findsOneWidget);
      expect((cubit.state as WorkspaceLoaded).effectiveSelectedIds, {'a', 'b'});
      expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('workspace-select-all')));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.check), findsNWidgets(4));
      await tester.tap(find.text('Первый'));
      await tester.pumpAndSettle();
      expect((cubit.state as WorkspaceLoaded).effectiveSelectedIds, {'b', 'c'});
      expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'redesigned popover renders count, fallback name and actions without overflow, dark: $dark',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = WorkspaceCubit(
          repository: _Repository(const [
            WorkspaceModel(id: 'a', name: 'Первый', color: '#6D5FE0'),
            WorkspaceModel(id: 'b', name: 'Второй', color: '#10B981'),
            WorkspaceModel(id: 'c', name: ''),
          ]),
          selectionStorage: const WorkspaceSelectionStorage(
            FlutterSecureStorage(),
          ),
        );
        addTearDown(cubit.close);
        await cubit.load();
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.4)),
                child: child!,
              ),
              home: const Scaffold(body: SafeArea(child: WorkspaceSwitcher())),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('workspace-switcher')));
        await tester.pumpAndSettle();
        expect(find.text('1/3'), findsOneWidget);
        expect(find.text('Без названия'), findsOneWidget);
        expect(find.text('Создать workspace'), findsOneWidget);
        expect(find.text('Архивированные'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
