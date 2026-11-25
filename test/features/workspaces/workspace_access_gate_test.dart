import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/workspaces/data/repositories/workspace_repository_impl.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/widgets/workspace_access_gate.dart';

class _Repository implements WorkspaceRepository {
  List<WorkspaceModel> items = [];
  Completer<List<WorkspaceModel>>? pending;
  bool failLoad = false, failCreate = false;
  int creations = 0;

  @override
  Future<List<WorkspaceModel>> getWorkspaces() async {
    if (failLoad) throw const WorkspaceException('Нет подключения');
    return pending == null ? items : await pending!.future;
  }

  @override
  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request) async {
    creations++;
    if (failCreate) throw const WorkspaceException('Не удалось создать');
    return WorkspaceModel(id: 'new', name: request.name);
  }

  @override
  Future<List<WorkspaceModel>> getArchivedWorkspaces() async => [];
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({
      'selected_workspace_id': 'old-account',
    });
  });

  for (final dark in [false, true]) {
    testWidgets(
      'first workspace gates requests and handles creation, dark: $dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository()..pending = Completer();
        const storage = WorkspaceSelectionStorage(FlutterSecureStorage());
        final cubit = WorkspaceCubit(
          repository: repository,
          selectionStorage: storage,
        );
        addTearDown(cubit.close);
        var protectedBuilds = 0;
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: WorkspaceAccessGate(
                onOpenMenu: () {},
                child: Builder(
                  builder: (_) {
                    protectedBuilds++;
                    return const Text('Рабочий экран');
                  },
                ),
              ),
            ),
          ),
        );
        final load = cubit.load();
        await tester.pump();
        expect(protectedBuilds, 0);
        repository.pending!.complete([]);
        await load;
        await tester.pumpAndSettle();
        expect(await storage.read(), isNull);
        expect(find.text('Создайте первое пространство'), findsOneWidget);
        expect(protectedBuilds, 0);
        await tester.ensureVisible(
          find.byKey(const Key('first-workspace-create')),
        );
        await tester.tap(find.byKey(const Key('first-workspace-create')));
        await tester.pumpAndSettle();
        expect(repository.creations, 0);
        expect(find.text('Введите название workspace.'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Личное');
        repository.failCreate = true;
        await tester.ensureVisible(
          find.byKey(const Key('first-workspace-create')),
        );
        await tester.tap(find.byKey(const Key('first-workspace-create')));
        await tester.pumpAndSettle();
        expect(find.text('Не удалось создать'), findsOneWidget);
        expect(protectedBuilds, 0);
        repository.failCreate = false;
        await tester.tap(find.byKey(const Key('first-workspace-create')));
        await tester.pumpAndSettle();
        expect(find.text('Рабочий экран'), findsOneWidget);
        expect(await storage.read(), 'new');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'load failure offers retry and an accepted invitation unlocks content',
    (tester) async {
      final repository = _Repository()..failLoad = true;
      final cubit = WorkspaceCubit(
        repository: repository,
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
            home: WorkspaceAccessGate(
              onOpenMenu: () {},
              child: const Text('Рабочий экран'),
            ),
          ),
        ),
      );
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      repository.failLoad = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      repository.items = [const WorkspaceModel(id: 'invited', name: 'Команда')];
      await tester.tap(find.text('Обновить список'));
      await tester.pumpAndSettle();
      expect(find.text('Рабочий экран'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
