import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_projects_card.dart';
import 'package:jospar/features/projects/data/models/create_project_request.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/domain/repositories/project_task_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';

void main() {
  testWidgets('shows four projects with their progress', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = ProjectsCubit(
      _ProjectRepository(
        List<ProjectModel>.generate(
          5,
          (index) => ProjectModel(
            id: 'project-$index',
            code: 'P$index',
            name: 'Проект $index',
            workspaceId: 'workspace',
            start: null,
            end: null,
            progress: index * 10,
          ),
        ),
      ),
      taskRepository: const _TaskRepository(<ProjectTaskModel>[
        ProjectTaskModel(id: 'task-1', projectId: 'project-3', status: 'DONE'),
        ProjectTaskModel(
          id: 'task-2',
          projectId: 'project-3',
          status: 'IN_PROGRESS',
          progress: 40,
        ),
      ]),
    );
    await cubit.loadForWorkspace('workspace');
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<ProjectsCubit>.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DashboardProjectsCard()),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dashboard-projects-card')), findsOneWidget);
    expect(find.text('Проекты'), findsOneWidget);
    expect(find.text('Задачи'), findsOneWidget);
    expect(find.text('Проект 0'), findsOneWidget);
    expect(find.text('Проект 3'), findsOneWidget);
    expect(find.text('Проект 4'), findsNothing);
    expect(find.text('50%'), findsOneWidget);
  });
}

class _TaskRepository implements ProjectTaskRepository {
  const _TaskRepository(this.tasks);

  final List<ProjectTaskModel> tasks;

  @override
  Future<List<ProjectTaskModel>> getTasksForProjectIds(
    List<String> projectIds,
  ) async => tasks;
}

class _ProjectRepository implements ProjectRepository {
  const _ProjectRepository(this.projects);

  final List<ProjectModel> projects;

  @override
  Future<List<ProjectModel>> getProjects() async => projects;

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) {
    throw UnimplementedError();
  }
}
