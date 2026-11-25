import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_date_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'planner_test_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';

void main() {
  testWidgets('returning to the app refreshes entries added on the web', (
    tester,
  ) async {
    final repository = _RefreshRepository();
    final cubit = PlannerCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      PlannerTestApp(
        child: BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: PlannerScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.loads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repository.items = [
      PlannerItemModel(
        id: 'web',
        title: 'Добавлено в вебе',
        plannedDate: DateTime.now(),
      ),
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(find.text('Добавлено в вебе'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows web-style three-hour labels and changes the selected day',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const PlannerTestApp(child: MaterialApp(home: PlannerScreen())),
      );

      expect(find.text('Ежедневник'), findsOneWidget);
      expect(find.text('День'), findsOneWidget);
      void expectSingleLineToolbar() {
        final date = tester.getCenter(
          find.byKey(const Key('planner-date-picker')),
        );
        final navigation = tester.getCenter(
          find.byKey(const Key('planner-next-day')),
        );
        expect(date.dy, closeTo(navigation.dy, 1));
      }

      expectSingleLineToolbar();
      expect(find.text('Сегодня'), findsNothing);
      for (final time in ['6:00', '9:00', '12:00', '15:00', '18:00']) {
        expect(find.text(time), findsOneWidget);
      }
      expect(find.text('7:00'), findsNothing);
      expect(find.text('Нет задач со сроком'), findsNothing);
      expect(find.text('GMT+5'), findsNothing);
      expect(find.byKey(const Key('planner-hour-9')), findsNothing);

      final selectedDate = find.byKey(const Key('planner-selected-date'));
      final initialText = tester.widget<Text>(selectedDate).data;

      await tester.tap(find.byKey(const Key('planner-next-day')));
      await tester.pumpAndSettle();

      final nextDayText = tester.widget<Text>(selectedDate).data;
      expect(nextDayText, isNot(initialText));
      expect(find.byKey(const Key('planner-today')), findsNothing);
      await tester.tap(find.byKey(const Key('planner-date-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(PlannerDatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      for (final mode in ['week', 'month', 'day']) {
        await tester.tap(find.byKey(const Key('planner-view-selector')));
        await tester.pumpAndSettle();
        expect(
          find.text(switch (mode) {
            'week' => 'Неделя',
            'month' => 'Месяц',
            _ => 'День',
          }),
          findsOneWidget,
        );
        expectSingleLineToolbar();
        expect(tester.takeException(), isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

class _RefreshRepository implements PlannerRepository {
  @override
  Future<void> updateExtras(
    String itemId, {
    bool updateIcon = false,
    String? icon,
    List<TaskChecklistModel>? checklists,
  }) async {}

  int loads = 0;
  List<PlannerItemModel> items = [];
  @override
  Future<List<PlannerItemModel>> load() async {
    loads++;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
