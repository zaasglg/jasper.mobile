import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_cache.dart';
import 'package:jospar/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_state.dart';

void main() {
  test(
    'board loads every page and filters/counts include tasks after first 100',
    () async {
      final adapter = _Adapter(count: 257);
      final cache = KanbanBoardCache();
      final cubit = KanbanCubit(_repo(adapter), cache: cache);
      await cubit.load('p');
      expect(cubit.state.tasks.length, 257);
      expect(adapter.pages.map((r) => r.queryParameters['skip']), [
        0,
        100,
        200,
      ]);
      expect(
        adapter.pages.every(
          (r) =>
              r.queryParameters['projectId'] == 'p' &&
              r.queryParameters['archived'] == false &&
              r.queryParameters['take'] == 100,
        ),
        isTrue,
      );
      expect(cache.read('p')!.tasks.length, 257);
      final todo = cubit.state.columns.firstWhere((c) => c.statusMap == 'TODO');
      expect(cubit.state.tasksFor(todo).length, 129);
      cubit.setSearch('Task 256');
      expect(cubit.state.tasksFor(todo).single.id, 'p-256');
      await cubit.close();
    },
  );
  test('full last page requests an empty page, removing duplicates', () async {
    final adapter = _Adapter(count: 200)..duplicate = true;
    final board = await _repo(adapter).loadBoard('p');
    expect(board.tasks.length, 199);
    expect(adapter.pages.map((r) => r.queryParameters['skip']), [0, 100, 200]);
  });
  test('empty board terminates on first page', () async {
    final adapter = _Adapter(count: 0);
    expect((await _repo(adapter).loadBoard('p')).tasks, isEmpty);
    expect(adapter.pages.length, 1);
  });
  test(
    'later-page failure never replaces complete cache with first page',
    () async {
      final adapter = _Adapter(count: 257);
      final cache = KanbanBoardCache();
      final cubit = KanbanCubit(_repo(adapter), cache: cache);
      await cubit.load('p');
      adapter.count = 320;
      adapter.failSecond = true;
      await cubit.load('p', refresh: true);
      expect(cubit.state.status, KanbanStatus.success);
      expect(cubit.state.tasks.length, 257);
      expect(cubit.state.actionErrorMessage, isNotNull);
      expect(cache.read('p')!.tasks.length, 257);
      adapter.failSecond = false;
      await cubit.load('p', refresh: true);
      expect(cubit.state.tasks.length, 320);
      expect(cache.read('p')!.tasks.length, 320);
      await cubit.close();
    },
  );
  test(
    'server ignoring skip reports incomplete board instead of looping',
    () async {
      final adapter = _Adapter(count: 200)..repeat = true;
      await expectLater(
        _repo(adapter).loadBoard('p'),
        throwsA(isA<KanbanException>()),
      );
      expect(adapter.pages.length, 2);
    },
  );
  test(
    'cancelling on page two aborts loading and no page three is requested',
    () async {
      final adapter = _Adapter(count: 250)..holdSecond = true;
      final repo = _repo(adapter);
      final load = repo.loadBoard('p');
      await adapter.secondStarted.future;
      repo.cancelPendingLoads();
      await expectLater(
        load,
        throwsA(
          isA<KanbanException>().having(
            (e) => e.message,
            'cancel',
            'Запрос отменён.',
          ),
        ),
      );
      expect(adapter.pages.map((r) => r.queryParameters['skip']), [0, 100]);
    },
  );
  test(
    'project switch cancels old pagination and only caches the new project',
    () async {
      final adapter = _Adapter(count: 250)..holdSecond = true;
      final cache = KanbanBoardCache();
      final cubit = KanbanCubit(_repo(adapter), cache: cache);
      final old = cubit.load('p');
      await adapter.secondStarted.future;
      await cubit.load('new');
      await old;
      expect(cubit.state.projectId, 'new');
      expect(cubit.state.tasks.length, 250);
      expect(cubit.state.tasks.every((t) => t.projectId == 'new'), isTrue);
      expect(cache.read('p'), isNull);
      expect(cache.read('new')!.tasks.length, 250);
      await cubit.close();
    },
  );
}

KanbanRepositoryImpl _repo(_Adapter adapter) => KanbanRepositoryImpl(
  Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
    ..httpClientAdapter = adapter,
);

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.count});
  int count;
  bool duplicate = false,
      failSecond = false,
      repeat = false,
      holdSecond = false;
  final secondStarted = Completer<void>();
  final requests = <RequestOptions>[];
  Iterable<RequestOptions> get pages =>
      requests.where((r) => r.path == 'project-tasks');
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final project = options.queryParameters['projectId'];
    Object data;
    var code = 200;
    if (options.path == 'kanban-columns') {
      data = [
        {
          'id': 'todo',
          'projectId': project,
          'name': 'К работе',
          'statusMap': 'TODO',
        },
        {
          'id': 'done',
          'projectId': project,
          'name': 'Готово',
          'statusMap': 'DONE',
        },
      ];
    } else {
      final skip = options.queryParameters['skip'] as int;
      if (holdSecond && project == 'p' && skip == 100) {
        if (!secondStarted.isCompleted) secondStarted.complete();
        await cancelFuture;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      }
      final start = repeat ? 0 : skip;
      if (failSecond && skip > 0) {
        code = 503;
        data = {};
      } else {
        data = {
          'data': {
            'tasks': [
              for (
                var i = start;
                i < count &&
                    i < start + (options.queryParameters['take'] as int);
                i++
              )
                {
                  'id': '$project-${duplicate && i == 100 ? 99 : i}',
                  'projectId': project,
                  'title': 'Task $i',
                  'status': i.isEven ? 'TODO' : 'DONE',
                },
            ],
          },
        };
      }
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
