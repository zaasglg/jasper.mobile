import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_state.dart';
import 'package:jospar/features/projects/presentation/screens/projects_screen.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

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
  testWidgets('search works without status filters on a narrow mobile screen', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final projects = _Projects();
    final workspace = _Workspace();
    addTearDown(projects.close);
    addTearDown(workspace.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
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
    expect(find.text('Выполнено'), findsOneWidget);
    expect(find.text('Ботаника'), findsNothing);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pump();
    expect(find.text('Ботаника'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
