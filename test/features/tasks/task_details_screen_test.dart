import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/domain/repositories/task_details_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:jospar/features/tasks/presentation/screens/task_details_screen.dart';

void main() {
  testWidgets('renders the task detail on a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _DetailsRepository();
    final cubit = TaskDetailsCubit(repository, _ProfileRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<TaskDetailsCubit>.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загрузка задачи…'), findsOneWidget);

    await cubit.load('task-1');
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('OPB-42'), findsOneWidget);
    expect(find.text('Мобильная задача'), findsOneWidget);
    expect(find.text('Ресурс'), findsOneWidget);
    expect(find.text('Чек-листы'), findsOneWidget);
    final budgetPosition = tester.getTopLeft(find.text('Бюджет'));
    final materialsPosition = tester.getTopLeft(find.text('Материалы'));
    expect(materialsPosition.dy, closeTo(budgetPosition.dy, 1));
    expect(materialsPosition.dx, greaterThan(budgetPosition.dx));
    expect(tester.takeException(), isNull);
  });
}

class _DetailsRepository implements TaskDetailsRepository {
  final TaskDetailsPayload payload = TaskDetailsPayload(
    task: const ProjectTaskModel(
      id: 'task-1',
      displayId: 'OPB-42',
      title: 'Мобильная задача',
      projectId: 'project-1',
      status: 'PROGRESS',
      progress: 35,
      assignees: <TaskAssigneeModel>[
        TaskAssigneeModel(userId: 'user-1', name: 'Данияр Исаев'),
      ],
      epics: <TaskEpicModel>[TaskEpicModel(id: 'epic-1', name: 'Архитектура')],
    ),
    detail: const TaskDetailModel(
      description: 'Описание задачи',
      checklists: <TaskChecklistModel>[
        TaskChecklistModel(
          id: 'checklist-1',
          name: 'Проверка',
          items: <TaskChecklistItemModel>[
            TaskChecklistItemModel(id: 'item-1', text: 'Первый пункт'),
          ],
        ),
      ],
      comments: <TaskCommentModel>[
        TaskCommentModel(
          id: 'comment-1',
          author: 'Данияр Исаев',
          text: 'Комментарий',
        ),
      ],
    ),
    resources: const <TaskResourceModel>[
      TaskResourceModel(
        id: 'resource-1',
        name: 'Бюджет',
        planValue: 1000,
        factValue: 500,
      ),
      TaskResourceModel(
        id: 'resource-2',
        name: 'Материалы',
        planValue: 300,
        factValue: 120,
      ),
    ],
  );

  @override
  Future<TaskDetailsPayload> getTask(String taskId) async => payload;

  @override
  Future<List<TaskHistoryEntryModel>> getHistory(String taskId) async {
    return const <TaskHistoryEntryModel>[];
  }

  @override
  Future<List<KanbanColumnModel>> getColumns(String projectId) async {
    return const <KanbanColumnModel>[
      KanbanColumnModel(
        id: 'column-1',
        name: 'Разработка',
        statusMap: 'PROGRESS',
        projectId: 'project-1',
      ),
    ];
  }

  @override
  Future<TaskDetailsPayload> updateDetail(
    String taskId,
    TaskDetailModel detail,
  ) async => payload.copyWith(detail: detail);

  @override
  Future<TaskDetailsPayload> updateEnd(String taskId, DateTime? end) async {
    return payload.copyWith(task: payload.task.copyWith(end: end));
  }

  @override
  Future<TaskDetailsPayload> updateProgress(String taskId, int progress) async {
    return payload.copyWith(
      task: payload.task.copyWith(progress: progress.toDouble()),
    );
  }
}

class _ProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async {
    return const UserProfile(
      id: 'user-1',
      name: 'Данияр Исаев',
      email: 'user@example.test',
    );
  }
}
