import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/features/planner/data/repositories/planner_week_order_repository_impl.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_week_order_cubit.dart';
import '../test/features/planner/planner_week_drag_test.dart' as gestures;
import '../test/features/planner/planner_week_order_test.dart'
    show weekDay, weekItem;

/// An isolated test identity. Never reads or overwrites the signed-in token.
class _TestIdentity extends AuthTokenStorage {
  _TestIdentity() : super(const FlutterSecureStorage());
  @override
  Future<String?> read() async =>
      'test.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'weekly-order-integration'})))}.test';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const restoring = bool.fromEnvironment('WEEK_ORDER_RESTORE_ONLY');
  const persistOnly = bool.fromEnvironment('WEEK_ORDER_PERSIST_ONLY');
  if (!restoring && !persistOnly) gestures.main();

  testWidgets(
    restoring
        ? 'restores weekly order after a fresh app launch'
        : 'persists weekly order to real device preferences',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final repository = PlannerWeekOrderRepositoryImpl(
        preferences,
        _TestIdentity(),
      );
      final cubit = PlannerWeekOrderCubit(
        repository,
        viewScope: 'integration:week-restart',
      );
      await cubit.initialize();
      final items = [weekItem('persist-a'), weekItem('persist-b')];
      if (restoring) {
        expect(
          PlannerWeekOrderCubit.ordered(
            weekDay,
            items,
            cubit.state.orders,
          ).map((item) => item.id),
          ['persist-b', 'persist-a'],
        );
        await preferences.remove(cubit.state.scope!);
      } else {
        await cubit.reorder(weekDay, ['persist-b', 'persist-a'], items);
        expect(cubit.state.error, isNull);
        expect(preferences.getString(cubit.state.scope!), isNotNull);
      }
      await cubit.close();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Week planner checks passed')),
          ),
        ),
      );
    },
  );
}
