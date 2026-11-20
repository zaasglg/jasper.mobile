import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/models/task_creation_models.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/tasks/data/repositories/task_creation_repository_impl.dart';
import 'package:jospar/features/tasks/domain/repositories/task_creation_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_creation_cubit.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';

void main() {
  test(
    'workspace/project switches clear dependent selections and ignore stale responses',
    () async {
      final repository = CreationFakeRepository();
      final cubit = TaskCreationCubit(repository);
      addTearDown(cubit.close);
      await cubit.initialize(workspaceId: 'w');
      expect(cubit.state.draft.projectId, 'p');
      expect(cubit.state.draft.status, 'TODO');
      expect(cubit.state.draft.position, 2);
      cubit.change(
        cubit.state.draft.copyWith(
          title: 'Новая задача',
          epicIds: ['e'],
          assigneeIds: ['v'],
        ),
      );
      final pending = Completer<TaskCreationOptions>();
      repository.pending = pending;
      final first = cubit.selectProject('p');
      repository.pending = null;
      await cubit.selectWorkspace('other');
      pending.complete(repository.defaultOptions);
      await first;
      expect(cubit.state.draft.workspaceId, 'other');
      expect(cubit.state.draft.projectId, 'other-project');
      expect(cubit.state.draft.epicIds, isEmpty);
      expect(cubit.state.draft.assigneeIds, isEmpty);
      expect(cubit.state.draft.title, 'Новая задача');
      expect(cubit.state.canSubmit, true);
    },
  );
  test(
    'validation, failed retry and duplicate taps retain one creation request in flight',
    () async {
      final repository = CreationFakeRepository();
      final cubit = TaskCreationCubit(repository);
      addTearDown(cubit.close);
      await cubit.initialize(workspaceId: 'w');
      expect(await cubit.submit(), null);
      expect(repository.requests, isEmpty);
      cubit.change(
        cubit.state.draft.copyWith(
          title: 'Согласовать план',
          estimateMinutes: 630,
          files: const [
            TaskFileModel(
              id: 'f',
              name: 'plan.txt',
              dataUrl: 'data:text/plain;base64,QQ==',
              size: 1,
            ),
          ],
        ),
      );
      repository.fail = true;
      expect(await cubit.submit(), null);
      expect(cubit.state.draft.files.length, 1);
      expect(cubit.state.draft.estimateMinutes, 630);
      repository.fail = false;
      final pending = repository.creation = Completer<TaskCreationResult>();
      final first = cubit.submit();
      expect(await cubit.submit(), null);
      expect(repository.requests.length, 2);
      pending.complete(
        TaskCreationResult(
          task: const ProjectTaskModel(
            id: 'new',
            projectId: 'p',
            status: 'TODO',
          ),
          workspaceId: 'w',
        ),
      );
      expect((await first)?.task.id, 'new');
      expect(cubit.state.result?.task.id, 'new');
      expect(await cubit.submit(), null);
      expect(repository.requests.length, 2);
    },
  );
  test(
    'request matches server DTO including exact estimate and attachments',
    () async {
      final adapter = CreationAdapter();
      final repository = TaskCreationRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final request = TaskCreationRequest(
        workspaceId: 'w',
        projectId: 'p',
        title: '  Согласовать план  ',
        status: 'PROGRESS',
        estimateMinutes: 630,
        end: DateTime.utc(2026, 11, 2, 12),
        epicIds: const ['e'],
        assigneeIds: const ['u'],
        files: const [
          TaskFileModel(
            id: 'f',
            name: 'plan.txt',
            type: 'text/plain',
            size: 1,
            dataUrl: 'data:text/plain;base64,QQ==',
          ),
        ],
      );
      final result = await repository.create(request, []);
      expect(result.task.id, 'new');
      final post = adapter.requests.single;
      expect(post.path, 'project-tasks');
      expect(post.method, 'POST');
      expect(post.headers['X-Workspace-Id'], 'w');
      final body = post.data as Map;
      expect(body.containsKey('workspaceId'), false);
      expect(body['title'], 'Согласовать план');
      expect(body['est'], 11);
      expect(body['detail']['estimateMinutes'], 630);
      expect(
        body['detail']['files'].single['dataUrl'],
        'data:text/plain;base64,QQ==',
      );
      expect(body['epicIds'], ['e']);
      expect(body['assigneeIds'], ['u']);
      expect(body['end'], '2026-11-02T12:00:00.000Z');
      expect(body.containsKey('order'), false);
    },
  );
  test(
    'middle position uses atomic insert-after, first-position partial error reports created task',
    () async {
      final adapter = CreationAdapter();
      final repository = TaskCreationRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      const request = TaskCreationRequest(
        workspaceId: 'w',
        projectId: 'p',
        title: 'План',
        status: 'TODO',
        position: 2,
      );
      const siblings = [
        ProjectTaskModel(id: 'first', projectId: 'p', status: 'TODO'),
        ProjectTaskModel(id: 'second', projectId: 'p', status: 'TODO'),
      ];
      await repository.create(request, siblings);
      expect(
        (adapter.requests.single.data as Map)['insertAfterTaskId'],
        'first',
      );
      adapter.requests.clear();
      adapter.failOrder = true;
      final result = await repository.create(
        request.copyWith(position: 1),
        siblings,
      );
      expect(result.task.id, 'new');
      expect(result.orderWarning, true);
      expect(adapter.requests.where((e) => e.method == 'POST').length, 1);
      expect(adapter.requests.last.path, 'project-tasks/batch-order');
      expect((adapter.requests.last.data as Map)['updates'], [
        {'id': 'new', 'order': 1},
        {'id': 'first', 'order': 2},
        {'id': 'second', 'order': 3},
      ]);
    },
  );
  test(
    'options parse real workspace membership and do not expose another project',
    () async {
      final adapter = CreationAdapter();
      final repository = TaskCreationRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      final projects = await repository.projects('w');
      expect(projects.map((e) => e.id), ['p']);
      final options = await repository.options('w', 'p');
      expect(options.columns.single.statusMap, 'TODO');
      expect(options.members.single.userId, 'u');
      expect(options.members.single.name, 'Алия');
      expect(options.epics.single.id, 'e');
      expect(options.tasks.single.id, 'existing');
      expect(
        adapter.requests.every((e) => e.headers['X-Workspace-Id'] == 'w'),
        true,
      );
    },
  );
}

class CreationFakeRepository implements TaskCreationRepository {
  final requests = <TaskCreationRequest>[];
  bool fail = false;
  Completer<TaskCreationOptions>? pending;
  Completer<TaskCreationResult>? creation;
  TaskCreationOptions get defaultOptions => const TaskCreationOptions(
    columns: [KanbanColumnModel(id: 'c', name: 'К работе', statusMap: 'TODO')],
    epics: [TaskEpicModel(id: 'e', name: 'Строительство')],
    members: [
      TaskAssigneeModel(userId: 'u', name: 'Алия'),
      TaskAssigneeModel(userId: 'v', name: 'Данияр'),
    ],
    tasks: [
      ProjectTaskModel(
        id: 'old',
        projectId: 'p',
        title: 'Старая задача',
        status: 'TODO',
        order: 1,
      ),
    ],
  );
  @override
  Future<TaskCreationCatalog> catalog() async => const TaskCreationCatalog(
    workspaces: [
      WorkspaceModel(id: 'w', name: 'Цифровизация'),
      WorkspaceModel(id: 'other', name: 'Другой workspace'),
    ],
    user: UserProfile(id: 'u', name: 'Алия', email: 'aliya@example.kz'),
  );
  @override
  Future<List<ProjectModel>> projects(String workspaceId) async => [
    ProjectModel(
      id: workspaceId == 'w' ? 'p' : 'other-project',
      code: 'P',
      name: 'Проект 12',
      workspaceId: workspaceId,
      start: null,
      end: null,
    ),
  ];
  @override
  Future<List<TaskAssigneeModel>> members(String workspaceId) async =>
      defaultOptions.members;
  @override
  Future<TaskCreationOptions> options(
    String workspaceId,
    String projectId,
  ) async => pending?.future ?? defaultOptions;
  @override
  Future<TaskCreationResult> create(
    TaskCreationRequest request,
    List<ProjectTaskModel> siblings,
  ) async {
    requests.add(request);
    if (fail) throw const TaskCreationException('Нет прав на создание');
    return creation?.future ??
        TaskCreationResult(
          task: ProjectTaskModel(
            id: 'new',
            projectId: request.projectId,
            title: request.title.trim(),
            status: request.status,
          ),
          workspaceId: request.workspaceId,
        );
  }
}

class CreationAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool failOrder = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    dynamic data;
    var status = 200;
    if (options.path == 'project-tasks/batch-order') {
      data = {};
      status = failOrder ? 403 : 200;
    } else if (options.path == 'project-tasks' && options.method == 'POST') {
      data = {
        'id': 'new',
        'projectId': 'p',
        'title': options.data['title'],
        'status': options.data['status'],
      };
    } else if (options.path == 'project-tasks') {
      data = [
        {'id': 'existing', 'projectId': 'p', 'status': 'TODO'},
      ];
    } else if (options.path == 'kanban-columns') {
      data = [
        {'id': 'c', 'projectId': 'p', 'name': 'К работе', 'statusMap': 'TODO'},
        {
          'id': 'bad',
          'projectId': 'p',
          'name': 'Архив',
          'statusMap': 'OLD',
          'archived': true,
        },
      ];
    } else if (options.path == 'epics') {
      data = [
        {'id': 'e', 'name': 'Строительство'},
      ];
    } else if (options.path.endsWith('/members')) {
      data = {
        'members': [
          {
            'userId': 'u',
            'user': {'id': 'u', 'name': 'Алия'},
          },
        ],
      };
    } else {
      data = [
        {'id': 'p', 'workspaceId': 'w', 'name': 'Проект 12'},
        {'id': 'other', 'workspaceId': 'other', 'name': 'Недоступный проект'},
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
