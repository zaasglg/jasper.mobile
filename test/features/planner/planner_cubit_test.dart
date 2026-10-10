import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';

void main() {
  test(
    'completion rolls back only the failed item while other updates survive',
    () async {
      final repo = _Repository();
      final cubit = PlannerCubit(repo);
      await cubit.configure('a');
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
    'a delayed update from previous workspace cannot alter the new workspace',
    () async {
      final repo = _Repository();
      final cubit = PlannerCubit(repo);
      await cubit.configure('a');
      final pending = cubit.toggle(cubit.state.items.first);
      await cubit.configure('b');
      repo.pending['one']!.completeError(const PlannerException('Ошибка'));
      await pending;
      expect(cubit.state.workspaceId, 'b');
      expect(cubit.state.items.first.completed, isFalse);
      expect(cubit.state.actionError, isNull);
      await cubit.close();
    },
  );
  test('UTC timestamps keep the correct Kazakhstan calendar date', () {
    final utc = DateTime.parse('2026-10-09T20:30:00Z');
    final local = plannerLocal(utc);
    expect(local.day, 10);
    expect(plannerClock(local), '01:30');
    expect(plannerInstant(DateTime(2026, 10, 10), 1, 30), utc);
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
  @override
  Future<List<PlannerItemModel>> load(String workspaceId) async => const [
    PlannerItemModel(id: 'one', title: 'First'),
    PlannerItemModel(id: 'two', title: 'Second'),
  ];
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
  Future<PlannerItemModel> create(
    String workspaceId, {
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
  Future<void> addTask(
    String workspaceId, {
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {}
}
