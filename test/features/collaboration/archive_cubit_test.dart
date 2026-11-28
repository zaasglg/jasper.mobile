import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/collaboration/domain/collaboration_repository.dart';
import 'package:jospar/features/collaboration/domain/entities/managed_space.dart';
import 'package:jospar/features/collaboration/domain/entities/space_kind.dart';
import 'package:jospar/features/collaboration/presentation/archive_screen.dart';

const _item = ManagedSpace(id: 'project', name: 'Project');

class _Repository implements CollaborationRepository {
  Completer<List<ManagedSpace>>? pendingLoad;
  Completer<void>? pendingAction;
  int loadCalls = 0;
  int actionCalls = 0;

  @override
  Future<List<ManagedSpace>> archived(SpaceKind kind, {String? workspaceId}) {
    loadCalls++;
    return pendingLoad?.future ?? Future.value([_item]);
  }

  @override
  Future<void> restore(SpaceKind kind, String id) {
    actionCalls++;
    return pendingAction?.future ?? Future.value();
  }

  @override
  Future<void> delete(SpaceKind kind, String id) => restore(kind, id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final remove in [false, true]) {
    for (final failLoad in [false, true]) {
      test(
        'late archive response is ignored after action (remove: $remove, error: $failLoad)',
        () async {
          final repository = _Repository();
          final cubit = ArchiveCubit(
            repository,
            SpaceKind.project,
            'workspace',
          );
          addTearDown(cubit.close);
          await cubit.load();
          repository.pendingLoad = Completer<List<ManagedSpace>>();
          final loading = cubit.load();
          await cubit.act(_item.id, remove);
          expect(cubit.state.items, isEmpty);
          if (failLoad) {
            repository.pendingLoad!.completeError(StateError('offline'));
          } else {
            repository.pendingLoad!.complete([_item]);
          }
          await loading;
          expect(cubit.state.items, isEmpty);
          expect(cubit.state.error, isNull);
          expect(cubit.state.loading, isFalse);
        },
      );
    }
  }

  test('refresh during an action cannot unlock duplicate writes', () async {
    final repository = _Repository()..pendingAction = Completer<void>();
    final cubit = ArchiveCubit(repository, SpaceKind.project, 'workspace');
    addTearDown(cubit.close);
    await cubit.load();
    final action = cubit.act(_item.id, false);
    await cubit.load();
    expect(cubit.state.busyId, _item.id);
    await cubit.act(_item.id, true);
    expect(repository.actionCalls, 1);
    expect(repository.loadCalls, 1);
    repository.pendingAction!.complete();
    await action;
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.busyId, isNull);
  });
}
