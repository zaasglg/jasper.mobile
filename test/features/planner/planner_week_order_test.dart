import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/planner_week_order_repository_impl.dart';
import 'package:jospar/features/planner/domain/repositories/planner_week_order_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_week_order_cubit.dart';

class MemoryWeekOrders implements PlannerWeekOrderRepository {
  String owner = 'a';
  final saved = <String, Map<String, List<String>>>{};
  final writes = <List<String>>[];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<String?> scope(String viewScope) async => '$owner:$viewScope';
  @override
  Future<Map<String, List<String>>> load(String scope) async =>
      saved[scope] ?? {};
  @override
  Future<void> save(String scope, Map<String, List<String>> orders) async {
    final wait = pending;
    pending = null;
    await wait?.future;
    if (fail) throw StateError('full');
    saved[scope] = orders;
    writes.add(orders.values.expand((ids) => ids).toList());
  }
}

final weekDay = DateTime(2026, 11, 23);
PlannerItemModel weekItem(String id, {DateTime? day, int hour = 10}) =>
    PlannerItemModel(
      id: id,
      taskId: 'shared-task',
      title: id,
      scheduledAt: DateTime(
        (day ?? weekDay).year,
        (day ?? weekDay).month,
        (day ?? weekDay).day,
        hour,
      ),
      durationMinutes: 45,
    );

void main() {
  test(
    'shared preferences isolate owner and scope and tolerate corrupt data',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tokens = AuthTokenStorage(const FlutterSecureStorage());
      String jwt(String id) =>
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.signature';
      await tokens.save(jwt('a'));
      final repo = PlannerWeekOrderRepositoryImpl(prefs, tokens);
      final a = (await repo.scope('account'))!;
      final workspace = (await repo.scope('workspace:one'))!;
      await repo.save(a, {
        '2026-11-23': ['b', 'a'],
      });
      expect(await repo.load(a), {
        '2026-11-23': ['b', 'a'],
      });
      expect(await repo.load(workspace), isEmpty);
      await tokens.save(jwt('b'));
      expect(await repo.load((await repo.scope('account'))!), isEmpty);
      await prefs.setString(a, '{bad');
      expect(await repo.load(a), isEmpty);
      await prefs.setString(a, '{"2026-11-23":["b",4,"b","a"],"bad":false}');
      expect(await repo.load(a), {
        '2026-11-23': ['b', 'a'],
      });
    },
  );
  test(
    'week order survives restart, refresh, new/deleted/moved items without changing timestamps',
    () async {
      final repository = MemoryWeekOrders();
      var cubit = PlannerWeekOrderCubit(repository);
      await cubit.initialize();
      final items = [
        weekItem('a'),
        weekItem('b', hour: 11),
        weekItem('c', hour: 12),
      ];
      final before = items.map((e) => e.toJson()).toList();
      await cubit.reorder(weekDay, ['c', 'a', 'b'], items);
      expect(items.map((e) => e.toJson()).toList(), before);
      await cubit.close();
      cubit = PlannerWeekOrderCubit(repository);
      await cubit.initialize();
      expect(
        PlannerWeekOrderCubit.ordered(
          weekDay,
          items,
          cubit.state.orders,
        ).map((e) => e.id),
        ['c', 'a', 'b'],
      );
      final updated = [
        weekItem('b', day: DateTime(2026, 11, 24)),
        weekItem('a'),
        weekItem('new', hour: 8),
      ];
      expect(
        PlannerWeekOrderCubit.ordered(
          weekDay,
          updated,
          cubit.state.orders,
        ).map((e) => e.id),
        ['a', 'new'],
      );
      expect(
        PlannerWeekOrderCubit.ordered(
          DateTime(2026, 11, 24),
          updated,
          cubit.state.orders,
        ).map((e) => e.id),
        ['b'],
      );
      await cubit.close();
    },
  );
  test(
    'save failure rolls back; account switch ignores late results',
    () async {
      final repository = MemoryWeekOrders();
      final cubit = PlannerWeekOrderCubit(repository);
      await cubit.initialize();
      final items = [weekItem('a'), weekItem('b')];
      repository.fail = true;
      await cubit.reorder(weekDay, ['b', 'a'], items);
      expect(cubit.state.orders, isEmpty);
      expect(cubit.state.error, isNotNull);
      repository.fail = false;
      final pending = Completer<void>();
      repository.pending = pending;
      final save = cubit.reorder(weekDay, ['b', 'a'], items);
      repository.owner = 'b';
      authSession.markAuthenticated();
      await Future<void>.delayed(Duration.zero);
      pending.complete();
      await save;
      expect(cubit.state.scope, 'b:account');
      expect(cubit.state.orders, isEmpty);
      await cubit.close();
    },
  );
}
