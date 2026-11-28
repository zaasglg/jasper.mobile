import 'package:go_router/go_router.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_state.dart';
import 'package:jospar/features/projects/presentation/screens/projects_screen.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

class _Profile extends Cubit<ProfileState> implements ProfileCubit {
  _Profile() : super(const ProfileInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Projects extends Cubit<ProjectsState> implements ProjectsCubit {
  _Projects()
    : super(
        const ProjectsState(
          projects: [
            ProjectModel(
              id: '1',
              code: 'ORB',
              name: 'Орбита',
              workspaceId: 'w',
              start: null,
              end: null,
            ),
            ProjectModel(
              id: '2',
              code: 'BOT',
              name: 'Ботаника',
              description: 'Помощь лаборатории',
              workspaceId: 'w',
              start: null,
              end: null,
            ),
          ],
          projectTaskProgress: {'2': 100},
        ),
      );
  @override
  Future<void> loadForWorkspace(
    String workspaceId, {
    bool refresh = false,
  }) async {}
  @override
  Future<String?> setPinned(String id, bool pinned) async {
    emit(
      state.copyWith(
        projects: [
          for (final p in state.projects)
            p.id == id ? p.copyWith(isPinned: pinned) : p,
        ],
      ),
    );
    return null;
  }

  @override
  void selectProject(String id) => emit(state.copyWith(selectedProjectId: id));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workspace extends Cubit<WorkspaceState> implements WorkspaceCubit {
  _Workspace()
    : super(
        const WorkspaceLoaded(
          workspaces: [
            WorkspaceModel(id: 'w', name: 'Цифровизация', color: '#123456'),
          ],
          selected: WorkspaceModel(
            id: 'w',
            name: 'Цифровизация',
            color: '#123456',
          ),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'project workspace labels appear for multiple selection in list and grid',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = _Profile();
      final projects = _Projects();
      final workspace = _Workspace();
      addTearDown(profile.close);
      addTearDown(projects.close);
      addTearDown(workspace.close);
      projects.emit(
        projects.state.copyWith(
          projects: [
            projects.state.projects.first,
            projects.state.projects.last.copyWith(workspaceId: 'other'),
          ],
        ),
      );
      final single = workspace.state as WorkspaceLoaded;
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const ProjectsScreen())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ProfileCubit>.value(value: profile),
            BlocProvider<ProjectsCubit>.value(value: projects),
            BlocProvider<WorkspaceCubit>.value(value: workspace),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('project-workspace-1')), findsNothing);
      workspace.emit(
        single.copyWith(
          workspaces: [
            ...single.workspaces,
            const WorkspaceModel(
              id: 'other',
              name: 'Другой воркспейс с длинным названием',
            ),
          ],
          selectedIds: {'w', 'other'},
        ),
      );
      await tester.pumpAndSettle();
      for (final view in ['projects-list-view', 'projects-card-view']) {
        await tester.tap(find.byKey(Key(view)));
        await tester.pumpAndSettle();
        final first = find.byKey(const Key('project-workspace-1'));
        final second = find.byKey(const Key('project-workspace-2'));
        expect(tester.widget<Text>(first).data, 'Цифровизация');
        expect(
          tester.widget<Text>(second).data,
          'Другой воркспейс с длинным названием',
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('project-row-1')),
            matching: first,
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('project-row-2')),
            matching: second,
          ),
          findsOneWidget,
        );
        final firstRow = find.byKey(const Key('project-row-1'));
        expect(
          find.descendant(
            of: firstRow,
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          tester.getTopLeft(first).dy,
          lessThan(tester.getTopLeft(find.text('Орбита')).dy),
        );
        expect(tester.takeException(), isNull);
      }
      workspace.emit(single);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('project-workspace-1')), findsNothing);
      expect(find.byKey(const Key('project-workspace-2')), findsNothing);
    },
  );

  testWidgets('subprojects appear inside parent and remain searchable', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = _Profile();
    final projects = _Projects();
    final workspace = _Workspace();
    addTearDown(profile.close);
    addTearDown(projects.close);
    addTearDown(workspace.close);
    projects.emit(
      ProjectsState(
        projects: [
          projects.state.projects.first,
          projects.state.projects.last.copyWith(parentId: '1'),
        ],
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProjectsScreen()),
        GoRoute(
          path: '/manage/projects/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Editing ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/projects/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProfileCubit>.value(value: profile),
          BlocProvider<ProjectsCubit>.value(value: projects),
          BlocProvider<WorkspaceCubit>.value(value: workspace),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Подпроекты'), findsOneWidget);
    expect(find.byKey(const Key('project-row-2')), findsNothing);
    expect(find.byKey(const Key('subproject-2')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subproject-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subproject-2')), findsNothing);
    await tester.tap(find.byKey(const Key('projects-card-view')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subproject-2')), findsNothing);
    await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subproject-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final subproject = find.byKey(const Key('subproject-2'));
    final zero = find.descendant(of: subproject, matching: find.text('0%'));
    final title = find.descendant(
      of: subproject,
      matching: find.text('Ботаника'),
    );
    expect(
      (tester.getTopLeft(zero).dy - tester.getTopLeft(title).dy).abs(),
      lessThan(4),
    );
    final heading = find.text('Подпроекты');
    final count = find.text('· 1');
    expect(
      tester.getTopLeft(count).dx - tester.getTopRight(heading).dx,
      lessThan(12),
    );
    final group = find.byKey(const ValueKey('group-1-w'));
    final expandedHeight = tester.getSize(group).height;
    await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
    await tester.pumpAndSettle();
    expect(tester.getSize(group).height, lessThan(expandedHeight));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
    await tester.pumpAndSettle();
    // Moving a child out of its parent must keep the active drag alive,
    // including when the card changes columns in the grid.
    for (final view in ['projects-list-view', 'projects-card-view']) {
      await tester.tap(find.byKey(Key(view)));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('subproject-2')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
        await tester.pumpAndSettle();
      }
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('subproject-2'))),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final parent = tester.getRect(find.byKey(const Key('project-row-1')));
      await gesture.moveTo(Offset(parent.center.dx, parent.top + 5));
      await tester.pump();
      expect(find.byKey(const Key('project-row-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await gesture.moveTo(const Offset(380, 800));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      if (find.byKey(const Key('subproject-2')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('subproject-2')), findsOneWidget);
      expect(find.byKey(const Key('project-row-2')), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const Key('project-edit-1')));
    await tester.pumpAndSettle();
    expect(find.text('Editing 1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    if (find.byKey(const Key('subproject-2')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('project-pin-1')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Открепить проект'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-pin-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-edit-1')), findsOneWidget);
    expect(find.byKey(const Key('project-pin-1')), findsOneWidget);
    expect(find.byKey(const Key('project-archive-1')), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Ботаника');
    await tester.pumpAndSettle();
    expect(find.text('Орбита'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('subproject-2')),
        matching: find.text('Ботаника'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('projects-list-view')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-subprojects-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-edit-1')), findsOneWidget);
    expect(find.byKey(const Key('project-archive-1')), findsNothing);
    await tester.tap(find.byKey(const Key('project-pin-1')));
    await tester.pumpAndSettle();
    expect(projects.state.projects.first.isPinned, isTrue);
    expect(find.byKey(const Key('subproject-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('subproject-2')));
    await tester.pumpAndSettle();
    expect(find.text('Opened 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search works without status filters on a narrow mobile screen', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = _Profile();
    addTearDown(profile.close);
    final projects = _Projects();
    final workspace = _Workspace();
    addTearDown(projects.close);
    addTearDown(workspace.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProfileCubit>.value(value: profile),
          BlocProvider<ProjectsCubit>.value(value: projects),
          BlocProvider<WorkspaceCubit>.value(value: workspace),
        ],
        child: const MaterialApp(home: ProjectsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Орбита'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Ботаника'), findsOneWidget);
    await tester.tap(find.byKey(const Key('projects-list-view')));
    await tester.pumpAndSettle();
    expect(find.text('Выполнено'), findsNothing);
    expect(find.text('Орбита'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'лаборатории');
    await tester.pump();
    expect(find.text('Ботаника'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'нет совпадений');
    await tester.pump();
    expect(find.text('Проекты не найдены'), findsOneWidget);
    await tester.tap(find.text('Сбросить поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Орбита'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'orb');
    await tester.pump();
    expect(find.text('Орбита'), findsOneWidget);
    expect(find.text('Ботаника'), findsNothing);
    await tester.tap(find.byKey(const Key('projects-card-view')));
    await tester.pumpAndSettle();
    expect(find.text('Выполнено'), findsNothing);
    expect(find.text('Ботаника'), findsNothing);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pump();
    expect(find.text('Ботаника'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final first = find.byKey(const Key('project-row-1'));
    final second = find.byKey(const Key('project-row-2'));
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(
      tester.getTopLeft(second).dx,
      greaterThan(tester.getTopLeft(first).dx),
    );
    // Large system text switches to one column instead of squeezing labels.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final firstX = tester.getTopLeft(first).dx;
    await tester.scrollUntilVisible(
      second,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.getTopLeft(second).dx, firstX);
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(1024, 800);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(tester.takeException(), isNull);
  });
}
