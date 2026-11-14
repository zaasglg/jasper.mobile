import 'package:jospar/features/assistant/data/services/assistant_task_changes.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';

void main() {
  test(
    'task invalidation during mutation refreshes after it completes',
    () async {
      final repo = _Repository();
      final cubit = PlannerCubit(repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      final before = repo.loads;
      final operation = cubit.toggle(cubit.state.items.first);
      notifyAssistantTaskChanges();
      expect(repo.loads, before);
      repo.pending['one']!.complete();
      await operation;
      expect(repo.loads, before + 1);
    },
  );

  test(
    'task changes refresh configured planner and listener is removed on close',
    () async {
      final repo = _Repository();
      final cubit = PlannerCubit(repo);
      await cubit.initialize();
      final before = repo.loads;
      notifyAssistantTaskChanges();
      await Future<void>.delayed(Duration.zero);
      expect(repo.loads, before + 1);
      await cubit.close();
      notifyAssistantTaskChanges();
      await Future<void>.delayed(Duration.zero);
      expect(repo.loads, before + 1);
    },
  );
  test(
    'completion rolls back only the failed item while other updates survive',
    () async {
      final repo = _Repository();
      final cubit = PlannerCubit(repo);
      await cubit.initialize();
      final first = cubit.toggle(cubit.state.items[0]);
      final second = cubit.toggle(cubit.state.items[1]);
      expect(cubit.state.items.every((e) => e.completed), isTrue);
      repo.pending['two']!.complete();
      await second;
      repo.pending['one']!.completeError(const PlannerException('Ошибка сети'));
      await first;
      expect(cubit.state.items[0].completed, isFalse);
      expect(cubit.state.items[1].completed, isTrue);
      expect(cubit.state.actionError, 'Ошибка сети');
      expect(cubit.state.busyIds, isEmpty);
      await cubit.close();
    },
  );
  test(
    'initialization is idempotent and does not reset pending edits',
    () async {
      final repo = _Repository();
      final cubit = PlannerCubit(repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      final pending = cubit.toggle(cubit.state.items.first);
      await cubit.initialize();
      expect(repo.loads, 1);
      expect(cubit.state.items.first.completed, isTrue);
      repo.pending['one']!.complete();
      await pending;
      expect(cubit.state.items.first.completed, isTrue);
    },
  );
  test('UTC timestamps use the device calendar and round trip', () {
    final utc = DateTime.parse('2026-10-09T20:30:00Z');
    final local = plannerLocal(utc);
    expect(local, utc.toLocal());
    expect(plannerInstant(local, local.hour, local.minute), utc);
  });
  test('parses linked project, Inbox and standalone items', () {
    for (final json in [
      {
        'id': 'a',
        'taskId': 'task',
        'task': {
          'id': 'task',
          'projectId': 'p',
          'title': 'Project',
          'status': 'TODO',
          'progress': 100,
        },
      },
      {
        'id': 'b',
        'inboxTaskId': 'inbox',
        'inboxTask': {
          'id': 'inbox',
          'title': 'Inbox',
          'detail': {'completed': true},
        },
      },
      {'id': 'c', 'title': 'Standalone', 'completed': true},
    ]) {
      final item = PlannerItemModel.fromJson(json);
      expect(item.completed, isTrue);
      expect(PlannerItemModel.fromJson(item.toJson()), item);
    }
  });
}

class _Repository implements PlannerRepository {
  final pending = <String, Completer<void>>{};
  int loads = 0;
  @override
  Future<List<PlannerItemModel>> load() async {
    loads++;
    return const [
      PlannerItemModel(id: 'one', title: 'First'),
      PlannerItemModel(id: 'two', title: 'Second'),
    ];
  }

  @override
  Future<void> update(
    PlannerItemModel item, {
    String? title,
    DateTime? scheduledAt,
    int? durationMinutes,
    bool? completed,
  }) async {
    await (pending[item.id] = Completer<void>()).future;
  }

  @override
  Future<PlannerItemModel> create({
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async => PlannerItemModel(
    id: 'new',
    title: title,
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
  );
  @override
  Future<void> remove(String itemId) async {}
  @override
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {}
}
