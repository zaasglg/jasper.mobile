import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/router/app_router.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_data.dart';
import 'package:jospar/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_state.dart';
import 'package:jospar/features/kanban/presentation/widgets/kanban_board.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_state.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

class _Profile extends Cubit<ProfileState> implements ProfileCubit {
  _Profile() : super(const ProfileInitial());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProjectModel _project(String id) => ProjectModel(
  id: id,
  code: id,
  name: 'Project $id',
  workspaceId: 'w',
  start: null,
  end: null,
);

class _Projects extends Cubit<ProjectsState> implements ProjectsCubit {
  _Projects() : super(ProjectsState(projects: [_project('a'), _project('b')]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workspace extends Cubit<WorkspaceState> implements WorkspaceCubit {
  _Workspace()
    : super(
        const WorkspaceLoaded(
          workspaces: [
            WorkspaceModel(id: 'w', name: 'Workspace', color: '#123456'),
          ],
          selected: WorkspaceModel(
            id: 'w',
            name: 'Workspace',
            color: '#123456',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

KanbanBoardData _board(String projectId, String title) => KanbanBoardData(
  columns: const [
    KanbanColumnModel(id: 'todo', name: 'To do', statusMap: 'TODO', order: 0),
  ],
  tasks: [
    ProjectTaskModel(
      id: '$projectId-task',
      projectId: projectId,
      status: 'TODO',
      title: title,
    ),
  ],
);

class _Repository implements KanbanRepository {
  final requests = <String>[];
  final responses = <Completer<KanbanBoardData>>[];

  @override
  Future<KanbanBoardData> loadBoard(
    String projectId, {
    String? search,
    int take = 100,
    int skip = 0,
  }) {
    requests.add(projectId);
    final response = Completer<KanbanBoardData>();
    responses.add(response);
    return response.future;
  }

  @override
  void cancelPendingLoads() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'switching projects replaces the board and ignores old responses',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final repository = _Repository();
      sl.registerFactory<KanbanCubit>(() => KanbanCubit(repository));
      addTearDown(sl.reset);
      final profile = _Profile();
      final projects = _Projects();
      final workspace = _Workspace();
      addTearDown(profile.close);
      addTearDown(projects.close);
      addTearDown(workspace.close);

      // Exercise the production route builder without unrelated shell services.
      final shell = appRouter.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      final projectRoute = shell.branches
          .expand((branch) => branch.routes)
          .whereType<GoRoute>()
          .singleWhere((route) => route.path == '/projects');
      final router = GoRouter(
        initialLocation: '/projects/a',
        routes: [
          GoRoute(
            path: '/projects',
            builder: (_, _) => const SizedBox(),
            routes: projectRoute.routes,
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
      await tester.pump();
      expect(repository.requests, ['a']);
      repository.responses[0].complete(_board('a', 'Task A'));
      await tester.pumpAndSettle();
      expect(find.text('Task A'), findsOneWidget);
      final previousCubit = tester
          .element(find.byType(KanbanBoard))
          .read<KanbanCubit>();

      final oldRefresh = previousCubit.load('a', refresh: true);
      router.go('/projects/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.requests, ['a', 'a', 'b']);
      expect(previousCubit.isClosed, isTrue);
      expect(find.text('Project b'), findsOneWidget);
      expect(find.text('Task A'), findsNothing);

      repository.responses[1].complete(_board('a', 'Late task A'));
      await oldRefresh;
      await tester.pump();
      expect(find.text('Late task A'), findsNothing);

      repository.responses[2].complete(_board('b', 'Task B'));
      await tester.pumpAndSettle();
      final currentCubit = tester
          .element(find.byType(KanbanBoard))
          .read<KanbanCubit>();
      expect(currentCubit.state.projectId, 'b');
      expect(currentCubit.state.status, KanbanStatus.success);
      expect(find.text('Task B'), findsOneWidget);
      expect(find.text('Task A'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
