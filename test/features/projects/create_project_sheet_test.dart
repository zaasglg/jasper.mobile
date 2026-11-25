import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/entities/create_project_request.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/domain/repositories/project_repository.dart';
import 'package:jospar/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:jospar/features/projects/presentation/widgets/create_project_sheet.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';

void main() {
  const sales = WorkspaceModel(id: 'w1', name: 'Продажи', color: '#2ab870');
  const support = WorkspaceModel(id: 'w2', name: 'Поддержка', color: '#3b82c4');

  testWidgets('create form validates required fields without an API call', (
    tester,
  ) async {
    final repository = _RecordingProjectRepository();
    final cubit = ProjectsCubit(repository);
    await _pumpSheet(tester, cubit, const <WorkspaceModel>[sales, support]);

    expect(find.text('Новый проект'), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('submit_project_button'))),
      isA<FButton>(),
    );
    expect(
      tester
          .widget<FButton>(find.byKey(const Key('cancel_project_button')))
          .variant,
      FButtonVariant.outline,
    );

    expect(find.text('Продажи'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('submit_project_button')));
    await tester.tap(find.byKey(const Key('submit_project_button')));
    await tester.pumpAndSettle();

    expect(find.text('Укажите название'), findsOneWidget);
    expect(repository.createCalls, 0);
    await cubit.close();
  });

  testWidgets('workspace dropdown controls workspaceId sent to create', (
    tester,
  ) async {
    final repository = _RecordingProjectRepository();
    final cubit = ProjectsCubit(repository);
    await cubit.loadForWorkspace(sales.id);
    await _pumpSheet(tester, cubit, const <WorkspaceModel>[sales, support]);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('project_name_field')),
        matching: find.byType(TextFormField),
      ),
      'Новый портал',
    );
    await tester.tap(find.byKey(const Key('project_workspace_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поддержка').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('submit_project_button')));
    await tester.tap(find.byKey(const Key('submit_project_button')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastRequest?.workspaceId, support.id);
    expect(repository.lastRequest?.code, startsWith('PRJ-'));
    expect(repository.lastRequest?.progress, 0);
    expect(repository.lastRequest?.isPinned, isFalse);
    await cubit.close();
  });
  testWidgets('subproject creation passes parent and locks workspace', (
    tester,
  ) async {
    final repository = _RecordingProjectRepository();
    final cubit = ProjectsCubit(repository);
    await cubit.loadForWorkspace(sales.id);
    const parent = ProjectModel(
      id: 'parent',
      code: 'PR',
      name: 'Основной',
      workspaceId: 'w1',
      start: null,
      end: null,
    );
    await _pumpSheet(tester, cubit, [sales, support], parent: parent);
    expect(find.text('Подпроект: Основной'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('project_name_field')),
        matching: find.byType(TextFormField),
      ),
      'Подпроект',
    );
    await tester.ensureVisible(find.byKey(const Key('submit_project_button')));
    await tester.tap(find.byKey(const Key('submit_project_button')));
    await tester.pumpAndSettle();
    expect(repository.lastRequest?.parentId, 'parent');
    expect(repository.lastRequest?.workspaceId, 'w1');
    await cubit.close();
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  ProjectsCubit cubit,
  List<WorkspaceModel> workspaces, {
  ProjectModel? parent,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider<ProjectsCubit>.value(
          value: cubit,
          child: CreateProjectSheet(
            workspaces: workspaces,
            initialWorkspace: workspaces.first,
            parent: parent,
          ),
        ),
      ),
    ),
  );
}

class _RecordingProjectRepository implements ProjectRepository {
  @override
  Future<void> setPinned(String id, bool pinned) async {}
  @override
  Future<void> archiveProject(String id) async {}

  @override
  Future<void> moveProject(
    String id, {
    required String workspaceId,
    String? parentId,
    String? anchorId,
    required String placement,
  }) async {}

  int createCalls = 0;
  CreateProjectRequest? lastRequest;

  @override
  Future<ProjectModel> createProject(CreateProjectRequest request) async {
    createCalls++;
    lastRequest = request;
    return ProjectModel(
      id: 'created',
      code: request.code,
      name: request.name,
      workspaceId: request.workspaceId,
      start: request.start,
      end: request.end,
    );
  }

  @override
  Future<List<ProjectModel>> getProjects() async => const <ProjectModel>[];
}
