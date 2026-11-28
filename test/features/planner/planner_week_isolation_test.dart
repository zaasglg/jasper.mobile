import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_week_order_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_day_agenda.dart';
import 'planner_test_app.dart';
import 'planner_week_drag_test.dart' show body, card, hold;
import 'planner_week_order_test.dart' show MemoryWeekOrders;

class _Planner implements PlannerRepository {
  _Planner(this.items);
  final List<PlannerItemModel> items;
  int loads = 0, mutations = 0;
  @override
  Future<List<PlannerItemModel>> load() async {
    loads++;
    return List.of(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutations++;
    throw StateError('Week drag called planner API');
  }
}

void main() {
  testWidgets(
    'week reorder makes no planner requests and day times and order stay unchanged',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final today = DateTime.now();
      final items = [
        for (var i = 0; i < 2; i++)
          PlannerItemModel(
            id: i == 0 ? 'a' : 'b',
            title: 'Task $i',
            scheduledAt: DateTime(today.year, today.month, today.day, 10 + i),
            durationMinutes: 30,
          ),
      ];
      final repository = _Planner(items);
      final planner = PlannerCubit(repository);
      final week = PlannerWeekOrderCubit(MemoryWeekOrders());
      sl.registerFactory<PlannerWeekOrderCubit>(() => week);
      addTearDown(() async {
        await sl.unregister<PlannerWeekOrderCubit>();
        if (!planner.isClosed) await planner.close();
      });
      await tester.pumpWidget(
        PlannerTestApp(
          child: BlocProvider.value(
            value: planner,
            child: const MaterialApp(home: PlannerScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialDay = tester
          .widget<PlannerDayAgenda>(find.byType(PlannerDayAgenda))
          .items
          .map((e) => e.toJson())
          .toList();
      await tester.tap(find.byKey(const Key('planner-view-selector')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        body('a'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('planner-week-view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final target = tester.getRect(card('b'));
      final gesture = await hold(tester, 'a');
      await gesture.moveTo(
        Offset(target.center.dx + target.width * .2, target.center.dy),
      );
      await tester.pump();
      expect(find.byKey(const Key('planner-week-insertion')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(week.state.orders.values.single, ['b', 'a']);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('planner-view-selector')));
        await tester.pumpAndSettle();
      }
      final restoredDay = tester
          .widget<PlannerDayAgenda>(find.byType(PlannerDayAgenda))
          .items
          .map((e) => e.toJson())
          .toList();
      expect(restoredDay, initialDay);
      expect(repository.loads, 1);
      expect(repository.mutations, 0);
      expect(planner.state.items, items);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
