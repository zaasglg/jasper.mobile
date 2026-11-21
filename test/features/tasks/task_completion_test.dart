import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/tasks/data/repositories/my_tasks_repository_impl.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';
import 'package:jospar/features/tasks/domain/entities/task_extra_field.dart';
import 'package:jospar/features/tasks/domain/repositories/my_task_fields_storage.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_cubit.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_details_cubit.dart';

class _Fields implements MyTaskFieldsStorage {
  @override
  Future<Set<TaskExtraField>> read() async => {};
  @override
  Future<void> save(Set<TaskExtraField> fields) async {}
}

class _Profile implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async =>
      const UserProfile(id: 'user', name: 'User', email: 'user@example.test');
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) => getCurrentUser();
}

class _TaskApi implements HttpClientAdapter {
  Map<String, dynamic> task = {
    'id': 'task',
    'projectId': 'project',
    'title': 'Task',
    'status': 'DONE',
    'progress': 100,
  };
  List<Map<String, dynamic>> columns = [
    {'id': 'todo', 'statusMap': 'TODO', 'order': 0},
    {'id': 'done', 'statusMap': 'DONE', 'order': 1},
  ];
  final patches = <Map<String, dynamic>>[];
  Completer<void>? patchGate;
  bool fail = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body;
    if (options.method == 'PATCH') {
      patches.add(Map<String, dynamic>.from(options.data as Map));
      await patchGate?.future;
      if (fail) return _json({}, 500);
      task = {...task, ...patches.last};
      body = task;
    } else {
      body = switch (options.path) {
        'project-tasks' => [task],
        'project-tasks/task' => task,
        'project-tasks/task/history' => [],
        'kanban-columns' => columns,
        _ => throw StateError('Unexpected request: ${options.path}'),
      };
    }
    return _json(body, 200);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  for (final view in ['my tasks', 'task details', 'kanban']) {
    group(view, () {
      late _TaskApi api;
      late ProjectTaskModel Function() current;
      late Future<void> Function() toggle;
      late Future<void> Function() reload;
      late Future<void> Function() initialize;

      setUp(() {
        api = _TaskApi();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'))
          ..httpClientAdapter = api;
        addTearDown(() => dio.close(force: true));
        if (view == 'my tasks') {
          final cubit = MyTasksCubit(
            repository: MyTasksRepositoryImpl(dio),
            fieldsStorage: _Fields(),
          );
          addTearDown(cubit.close);
          current = () => cubit.state.tasks.single;
          toggle = () => cubit.toggleTask(current());
          reload = () => cubit.refresh();
          initialize = () => cubit.configure(
            userId: 'user',
            projects: const [
              ProjectModel(
                id: 'project',
                code: 'P',
                name: 'Project',
                workspaceId: 'workspace',
                start: null,
                end: null,
              ),
            ],
          );
        } else if (view == 'task details') {
          final cubit = TaskDetailsCubit(
            TaskDetailsRepositoryImpl(dio),
            _Profile(),
          );
          addTearDown(cubit.close);
          current = () => cubit.state.task!;
          toggle = cubit.toggleCompleted;
          reload = cubit.refresh;
          initialize = () => cubit.load('task');
        } else {
          final cubit = KanbanCubit(KanbanRepositoryImpl(dio));
          addTearDown(cubit.close);
          current = () => cubit.state.tasks.single;
          toggle = () => cubit.toggleCompleted(current());
          reload = () => cubit.load('project', refresh: true);
          initialize = () => cubit.load('project');
        }
      });

      test(
        'reopening DONE persists both status and progress after reload',
        () async {
          await initialize();
          await toggle();
          expect(api.patches.single, {'progress': 0, 'status': 'TODO'});
          expect(current().isDone, isFalse);
          await reload();
          expect(current().isDone, isFalse);
          await toggle();
          expect(api.patches.last, {'progress': 100});
          await reload();
          expect(current().isDone, isTrue);
        },
      );

      test(
        'progress-only completion keeps the existing working status',
        () async {
          api.task['status'] = 'PROGRESS';
          await initialize();
          await toggle();
          expect(api.patches.single, {'progress': 0});
          await reload();
          expect(current().status, 'PROGRESS');
          expect(current().isDone, isFalse);
        },
      );

      test(
        'reopening falls back to TODO when columns are unavailable',
        () async {
          api.columns = [];
          await initialize();
          await toggle();
          expect(api.patches.single, {'progress': 0, 'status': 'TODO'});
          await reload();
          expect(current().isDone, isFalse);
        },
      );

      test('reopening selects the first active project column', () async {
        api.task['progress'] = null;
        api.columns = [
          {'id': 'done', 'statusMap': 'DONE', 'order': 0},
          {'id': 'archived', 'statusMap': 'OLD', 'order': 1, 'archived': true},
          {'id': 'empty', 'statusMap': '', 'order': 2},
          {
            'id': 'foreign',
            'statusMap': 'FOREIGN',
            'projectId': 'other',
            'order': 3,
          },
          {'id': 'later', 'statusMap': 'REVIEW', 'order': 5},
          {'id': 'active', 'statusMap': 'PROGRESS', 'order': 4},
        ];
        await initialize();
        await toggle();
        expect(api.patches.single, {'progress': 0, 'status': 'PROGRESS'});
        await reload();
        expect(current().isDone, isFalse);
      });

      test(
        'failed reopening restores both status and progress and can retry',
        () async {
          await initialize();
          api.patchGate = Completer<void>();
          api.fail = true;
          final pending = toggle();
          expect(current().status, 'TODO');
          expect(current().isDone, isFalse);
          api.patchGate!.complete();
          await pending;
          expect(current().status, 'DONE');
          expect(current().progress, 100);
          expect(current().isDone, isTrue);
          api.fail = false;
          await toggle();
          await reload();
          expect(current().isDone, isFalse);
        },
      );
    });
  }
}
