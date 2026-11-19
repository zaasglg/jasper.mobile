import 'package:jospar/features/assistant/data/services/assistant_task_changes.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_state.dart';

void main() {
  for (final operation in ['save', 'add']) {
    test(
      'failed $operation during refresh reconciles without stuck loading',
      () async {
        final repo = _Repository();
        final cubit = PlannerCubit(repo);
        addTearDown(cubit.close);
        await cubit.initialize();
        final staleLoad = repo.nextLoad = Completer<List<PlannerItemModel>>();
        final refresh = cubit.refresh();
        final addGate = repo.pendingAdd = Completer<void>();
        final write = operation == 'save'
            ? cubit.save(
                item: cubit.state.items.first,
                title: 'Changed',
                scheduledAt: DateTime(2026, 11, 18, 10),
                durationMinutes: 30,
              )
            : cubit.addTask(
                projectId: 'project',
                taskId: 'task',
                scheduledAt: DateTime(2026, 11, 18, 10),
                durationMinutes: 30,
              );
        // Even a response arriving while the write is pending must be ignored.
        staleLoad.complete(const [PlannerItemModel(id: 'stale', title: 'Old')]);
        await refresh;
        expect(cubit.state.items.first.id, 'one');
        final gate = operation == 'save' ? repo.pending['one']! : addGate;
        gate.completeError(const PlannerException('Ошибка сохранения'));
        expect(await write, isFalse);
        expect(cubit.state.status, PlannerStatus.success);
        expect(cubit.state.isSaving, isFalse);
        expect(cubit.state.actionError, 'Ошибка сохранения');
        expect(repo.loads, 3);
      },
    );
  }
  for (final reloadFails in [false, true]) {
    test(
      'failed toggle during refresh settles loading (reload fails: $reloadFails)',
      () async {
        final repo = _Repository();
        final cubit = PlannerCubit(repo);
        addTearDown(cubit.close);
        await cubit.initialize();
        final staleLoad = repo.nextLoad = Completer<List<PlannerItemModel>>();
        final refresh = cubit.refresh();
        expect(cubit.state.status, PlannerStatus.loading);
        final toggle = cubit.toggle(cubit.state.items.first);
        repo.loadError = reloadFails
            ? const PlannerException('Ошибка загрузки')
            : null;
        repo.pending['one']!.completeError(
          const PlannerException('Ошибка отметки'),
        );
        await toggle;
        staleLoad.complete(const [
          PlannerItemModel(id: 'stale', title: 'Old response'),
        ]);
        await refresh;
        expect(
          cubit.state.status,
          reloadFails ? PlannerStatus.failure : PlannerStatus.success,
        );
        expect(cubit.state.items.first.id, 'one');
        expect(cubit.state.items.first.completed, isFalse);
        expect(cubit.state.actionError, 'Ошибка отметки');
        expect(cubit.state.busyIds, isEmpty);
        expect(repo.loads, 3);
      },
    );
  }
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
        'completed': true,
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
        'completed': true,
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
  Completer<List<PlannerItemModel>>? nextLoad;
  Completer<void>? pendingAdd;
  PlannerException? loadError;
  int loads = 0;
  @override
  Future<List<PlannerItemModel>> load() async {
    loads++;
    final pendingLoad = nextLoad;
    nextLoad = null;
    if (pendingLoad != null) return pendingLoad.future;
    if (loadError != null) throw loadError!;
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
    DateTime? plannedDate,
    int? durationMinutes,
    bool? completed,
  }) async {
    await (pending[item.id] = Completer<void>()).future;
  }

  @override
  Future<PlannerItemModel> create({
    required String title,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
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
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) async {
    await pendingAdd?.future;
  }
}
