import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';

void main() {
  test(
    'created card inherits selected epics and is visible under active filter',
    () async {
      final adapter = _Adapter();
      final cubit = KanbanCubit(
        KanbanRepositoryImpl(Dio()..httpClientAdapter = adapter),
      );
      addTearDown(cubit.close);
      await cubit.load('p');
      cubit.setEpicFilter({'e1', 'e2'});
      expect(await cubit.createTask('TODO', '  Карточка  ', 'MED'), isTrue);
      expect(adapter.createdBody!['epicIds'], ['e1', 'e2']);
      expect(adapter.createdBody!['title'], 'Карточка');
      expect(cubit.state.tasksFor(cubit.state.columns.single).single.id, 'new');
      await cubit.load('p', refresh: true);
      expect(cubit.state.tasksFor(cubit.state.columns.single).single.id, 'new');
    },
  );

  test(
    'failed creation reports failure without adding a phantom task',
    () async {
      final adapter = _Adapter()..fail = true;
      final cubit = KanbanCubit(
        KanbanRepositoryImpl(Dio()..httpClientAdapter = adapter),
      );
      addTearDown(cubit.close);
      await cubit.load('p');
      expect(await cubit.createTask('TODO', 'Карточка', 'MED'), isFalse);
      expect(cubit.state.tasks, isEmpty);
      expect(cubit.state.actionErrorMessage, isNotEmpty);
    },
  );

  test('invalid success response is reported as a creation failure', () async {
    final adapter = _Adapter()..invalidResponse = true;
    final cubit = KanbanCubit(
      KanbanRepositoryImpl(Dio()..httpClientAdapter = adapter),
    );
    addTearDown(cubit.close);
    await cubit.load('p');
    expect(await cubit.createTask('TODO', 'Карточка', 'MED'), isFalse);
    expect(cubit.state.tasks, isEmpty);
  });
}

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic>? createdBody;
  bool fail = false;
  bool invalidResponse = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body;
    var status = 200;
    if (options.method == 'POST') {
      createdBody = Map<String, dynamic>.from(options.data as Map);
      status = fail ? 500 : 201;
      body = fail || invalidResponse
          ? <String, Object>{}
          : {'id': 'new', ...createdBody!};
    } else if (options.path == 'kanban-columns') {
      body = [
        {
          'id': 'todo',
          'name': 'К работе',
          'statusMap': 'TODO',
          'projectId': 'p',
        },
      ];
    } else {
      body = createdBody == null || fail
          ? []
          : [
              {
                'id': 'new',
                ...createdBody!,
                'epics': [
                  for (final id in createdBody!['epicIds'] as List) {'id': id},
                ],
              },
            ];
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
