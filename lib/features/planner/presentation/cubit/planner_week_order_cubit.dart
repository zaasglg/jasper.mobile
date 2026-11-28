import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_session.dart';
import '../../data/models/planner_item_model.dart';
import '../../domain/repositories/planner_week_order_repository.dart';
import '../../domain/utils/planner_dates.dart';

class PlannerWeekOrderState extends Equatable {
  const PlannerWeekOrderState({
    this.scope,
    this.ready = false,
    this.saving = false,
    this.orders = const {},
    this.error,
  });
  final String? scope, error;
  final bool ready, saving;
  final Map<String, List<String>> orders;
  @override
  List<Object?> get props => [scope, ready, saving, orders, error];
}

/// This state only projects week presentation; it never writes planner items.
class PlannerWeekOrderCubit extends Cubit<PlannerWeekOrderState> {
  PlannerWeekOrderCubit(this._repository, {this.viewScope = 'account'})
    : super(const PlannerWeekOrderState()) {
    authSession.addListener(initialize);
  }
  final PlannerWeekOrderRepository _repository;
  final String viewScope;
  int _revision = 0;

  Future<void> initialize() async {
    final revision = ++_revision;
    emit(const PlannerWeekOrderState());
    try {
      final scope = await _repository.scope(viewScope);
      if (isClosed || revision != _revision) return;
      if (scope == null) return;
      final orders = await _repository.load(scope);
      if (isClosed || revision != _revision) return;
      emit(PlannerWeekOrderState(scope: scope, orders: orders, ready: true));
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          const PlannerWeekOrderState(
            error: 'Не удалось загрузить порядок недели.',
          ),
        );
      }
    }
  }

  static List<PlannerItemModel> ordered(
    DateTime day,
    List<PlannerItemModel> items,
    Map<String, List<String>> orders,
  ) {
    final daily = items
        .where(
          (item) =>
              !item.archived &&
              item.day != null &&
              samePlannerDay(item.day!, day),
        )
        .toList();
    final sourceIndex = {for (var i = 0; i < daily.length; i++) daily[i].id: i};
    daily.sort((a, b) {
      final aTime = a.allDay ? null : a.scheduledAt;
      final bTime = b.allDay ? null : b.scheduledAt;
      final time = aTime == null
          ? (bTime == null ? 0 : -1)
          : bTime == null
          ? 1
          : aTime.compareTo(bTime);
      return time != 0
          ? time
          : sourceIndex[a.id]!.compareTo(sourceIndex[b.id]!);
    });
    final rank = {
      for (final (index, id)
          in (orders[plannerDayString(day)] ?? <String>[]).indexed)
        id: index,
    };
    final defaultRank = {
      for (final (index, item) in daily.indexed) item.id: index,
    };
    daily.sort((a, b) {
      final aRank = rank[a.id];
      final bRank = rank[b.id];
      if (aRank != null && bRank != null) return aRank.compareTo(bRank);
      if (aRank != null) return -1;
      if (bRank != null) return 1;
      return defaultRank[a.id]!.compareTo(defaultRank[b.id]!);
    });
    return daily;
  }

  Future<void> reorder(
    DateTime day,
    List<String> ids,
    List<PlannerItemModel> items,
  ) async {
    final before = state;
    if (!before.ready || before.saving || before.scope == null) return;
    final current = ordered(
      day,
      items,
      before.orders,
    ).map((e) => e.id).toList();
    if (ids.length != current.length ||
        ids.toSet().length != current.length ||
        !ids.toSet().containsAll(current)) {
      return;
    }
    if (_same(ids, current)) return;
    // Reconcile saved days against the authoritative loaded entries, without
    // mutating the source list or reusing any board/task IDs.
    final days = <String, List<PlannerItemModel>>{};
    for (final item in items) {
      if (!item.archived && item.day != null) {
        days.putIfAbsent(plannerDayString(item.day!), () => []).add(item);
      }
    }
    final orders = <String, List<String>>{
      for (final entry in days.entries)
        entry.key: ordered(
          DateTime.parse(entry.key),
          entry.value,
          before.orders,
        ).map((e) => e.id).toList(),
      plannerDayString(day): List.of(ids),
    };
    final revision = _revision;
    emit(
      PlannerWeekOrderState(
        scope: before.scope,
        ready: true,
        saving: true,
        orders: orders,
      ),
    );
    try {
      await _repository.save(before.scope!, orders);
      if (!isClosed && revision == _revision) {
        emit(
          PlannerWeekOrderState(
            scope: before.scope,
            ready: true,
            orders: orders,
          ),
        );
      }
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          PlannerWeekOrderState(
            scope: before.scope,
            ready: true,
            orders: before.orders,
            error: 'Не удалось сохранить порядок недели. Повторите попытку.',
          ),
        );
      }
    }
  }

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

  @override
  Future<void> close() {
    _revision++;
    authSession.removeListener(initialize);
    return super.close();
  }
}
