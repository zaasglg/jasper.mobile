import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_cache.dart';
import 'package:jospar/features/kanban/domain/entities/kanban_board_data.dart';
import 'package:jospar/features/kanban/domain/repositories/kanban_repository.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';

const _board = KanbanBoardData(
  columns: [],
  tasks: [
    ProjectTaskModel(id: 'private', projectId: 'project', status: 'TODO'),
  ],
);

class _DelayedRepository implements KanbanRepository {
  final response = Completer<KanbanBoardData>();
  bool cancelled = false;
  @override
  Future<KanbanBoardData> loadBoard(
    String projectId, {
    String? search,
    int take = 100,
    int skip = 0,
  }) => response.future;
  @override
  void cancelPendingLoads() => cancelled = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('cache is isolated across logout and fresh login', () {
    authSession.markAuthenticated();
    final cache = KanbanBoardCache()..write('project', _board);
    authSession.markUnauthenticated();
    authSession.markAuthenticated();
    expect(cache.read('project'), isNull);
  });

  test('old board response cannot populate a new-session cache', () async {
    authSession.markAuthenticated();
    final cache = KanbanBoardCache();
    final repository = _DelayedRepository();
    final cubit = KanbanCubit(repository, cache: cache);
    addTearDown(cubit.close);
    final pending = cubit.load('project');
    authSession.markUnauthenticated();
    authSession.markAuthenticated();
    repository.response.complete(_board);
    await pending;
    expect(cubit.state.tasks, isEmpty);
    expect(cache.read('project'), isNull);
    expect(repository.cancelled, isTrue);
  });
}
