import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/inbox/presentation/cubit/inbox_cubit.dart';

class _Repository implements InboxRepository {
  final List<InboxTaskModel> tasks = [];
  Future<List<InboxTaskModel>>? nextRead;
  Completer<void>? creating, completing;
  bool failRead = false;
  int posts = 0, completions = 0;
  @override
  Future<List<InboxTaskModel>> getInbox({
    bool archived = true,
    int sort = 1,
  }) async {
    if (failRead) throw StateError('Refresh failed');
    final pending = nextRead;
    nextRead = null;
    return pending ?? List.of(tasks);
  }

  @override
  Future<void> createInbox({required String title}) async {
    posts++;
    if (creating != null) await creating!.future;
    tasks.add(InboxTaskModel(id: 'created-$posts', title: title));
  }

  @override
  Future<void> completeInboxTask({required String id}) async {
    completions++;
    if (completing != null) await completing!.future;
    tasks.removeWhere((task) => task.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('acknowledged creation succeeds even when list refresh fails', () async {
    final repository = _Repository()..failRead = true;
    final cubit = InboxCubit(repository);
    addTearDown(cubit.close);
    expect(await cubit.create('Новая задача'), isTrue);
    expect(repository.posts, 1);
    expect(repository.tasks.single.title, 'Новая задача');
    expect(cubit.state.creationErrorMessage, isNull);
    expect(cubit.state.isCreating, isFalse);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('slow pre-create refresh cannot erase created task', () async {
    final old = Completer<List<InboxTaskModel>>();
    final repository = _Repository()..nextRead = old.future;
    final cubit = InboxCubit(repository);
    addTearDown(cubit.close);
    final refresh = cubit.load();
    expect(await cubit.create('Новая задача'), isTrue);
    old.complete([]);
    await refresh;
    expect(cubit.state.tasks.single.title, 'Новая задача');
  });

  test('refresh during create preserves submission lock', () async {
    final pending = Completer<void>();
    final repository = _Repository()..creating = pending;
    final cubit = InboxCubit(repository);
    addTearDown(cubit.close);
    final creating = cubit.create('Новая задача');
    await cubit.load();
    expect(cubit.state.isCreating, isTrue);
    expect(await cubit.create('Новая задача'), isFalse);
    pending.complete();
    expect(await creating, isTrue);
    expect(repository.posts, 1);
  });

  test(
    'refresh preserves completion lock and stale result cannot resurrect task',
    () async {
      const task = InboxTaskModel(id: 'task', title: 'Завершить');
      final repository = _Repository()..tasks.add(task);
      final cubit = InboxCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final old = Completer<List<InboxTaskModel>>();
      repository.nextRead = old.future;
      final refresh = cubit.load();
      final pending = Completer<void>();
      repository.completing = pending;
      final completing = cubit.complete('task');
      await cubit.load();
      expect(cubit.state.completingTaskIds, {'task'});
      expect(await cubit.complete('task'), isFalse);
      pending.complete();
      expect(await completing, isTrue);
      old.complete([task]);
      await refresh;
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.tasks, isEmpty);
      expect(repository.completions, 1);
    },
  );
}
