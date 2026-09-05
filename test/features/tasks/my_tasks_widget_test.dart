import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/tasks/domain/entities/task_extra_field.dart';
import 'package:jospar/features/tasks/domain/repositories/my_task_fields_storage.dart';
import 'package:jospar/features/tasks/domain/repositories/my_tasks_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:jospar/features/tasks/presentation/widgets/my_tasks_widget.dart';

void main() {
  testWidgets('renders mobile task rows and field controls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = MyTasksCubit(
      repository: const _Repository(),
      fieldsStorage: _Storage(),
    );
    await cubit.configure(
      userId: 'user',
      projects: const <ProjectModel>[
        ProjectModel(
          id: 'project',
          code: 'ORB',
          name: 'Orbita Platform Backend',
          workspaceId: 'workspace',
          start: null,
          end: null,
        ),
      ],
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<MyTasksCubit>.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: MyTasksWidget())),
        ),
      ),
    );

    expect(find.byKey(const Key('my-tasks-widget')), findsOneWidget);
    expect(find.text('Мои задачи'), findsOneWidget);
    expect(find.text('ORB-12'), findsOneWidget);
    expect(find.text('Подготовить мобильный релиз'), findsOneWidget);
    expect(find.text('К работе'), findsOneWidget);
    expect(find.text('Мобильное приложение'), findsOneWidget);
    expect(find.textContaining('Колонка ·'), findsNothing);
    expect(find.textContaining('Эпики ·'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('my-tasks-fields-button')));
    await tester.pumpAndSettle();
    expect(find.text('Показывать в списке'), findsOneWidget);
    expect(find.text('ID'), findsOneWidget);
    expect(find.text('Колонка'), findsOneWidget);
    expect(find.text('Эпики'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements MyTasksRepository {
  const _Repository();

  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const <String>[],
  }) async {
    return <ProjectTaskModel>[
      ProjectTaskModel(
        id: 'task',
        displayId: 'ORB-12',
        title: 'Подготовить мобильный релиз',
        projectId: 'project',
        status: 'TODO',
        end: DateTime(2026, 9, 8),
        epics: const <TaskEpicModel>[
          TaskEpicModel(id: 'epic', name: 'Мобильное приложение'),
        ],
      ),
    ];
  }

  @override
  Future<List<KanbanColumnModel>> getKanbanColumns(String projectId) async {
    return const <KanbanColumnModel>[
      KanbanColumnModel(id: 'todo', name: 'К работе', statusMap: 'TODO'),
    ];
  }

  @override
  Future<void> updateProgress(String taskId, int progress) async {}
}

class _Storage implements MyTaskFieldsStorage {
  @override
  Future<Set<TaskExtraField>> read() async => TaskExtraField.values.toSet();

  @override
  Future<void> save(Set<TaskExtraField> fields) async {}
}
