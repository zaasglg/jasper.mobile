import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_week_order_cubit.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_week_view.dart';
import 'planner_week_order_test.dart' show MemoryWeekOrders, weekDay, weekItem;

Finder card(String id) => find.byKey(ValueKey('planner-week-item-$id'));
Finder body(String id) => find.byKey(ValueKey('planner-week-open-$id'));
List<String> order(PlannerWeekOrderCubit cubit, List<PlannerItemModel> items) =>
    PlannerWeekOrderCubit.ordered(
      weekDay,
      items,
      cubit.state.orders,
    ).map((e) => e.id).toList();
Future<void> showWeek(
  WidgetTester tester,
  PlannerWeekOrderCubit cubit,
  List<PlannerItemModel> items, {
  ValueChanged<PlannerItemModel>? edit,
  ValueChanged<PlannerItemModel>? toggle,
  ValueChanged<PlannerItemModel>? remove,
  bool dark = false,
  String locale = 'ru',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      locale: Locale(locale),
      supportedLocales: const [Locale('ru'), Locale('kk')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: PlannerWeekView(
          selectedDate: weekDay,
          items: items,
          busyIds: const {},
          saving: false,
          orderCubit: cubit,
          onEdit: edit ?? (_) {},
          onToggle: toggle ?? (_) {},
          onRemove: remove ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> hold(WidgetTester tester, String id) async {
  final gesture = await tester.startGesture(tester.getCenter(body(id)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  return gesture;
}

void main() {
  for (final grid in [true, false]) {
    testWidgets(
      'same-day drag commits on drop only, cancels losslessly, grid $grid',
      (tester) async {
        final repo = MemoryWeekOrders();
        final cubit = PlannerWeekOrderCubit(repo);
        addTearDown(cubit.close);
        await cubit.initialize();
        final items = [
          weekItem('a'),
          weekItem('b'),
          weekItem('c'),
          weekItem('d'),
        ];
        final snapshot = items.map((e) => e.toJson()).toList();
        await showWeek(tester, cubit, items, dark: !grid);
        if (!grid) {
          await tester.tap(find.byKey(const ValueKey('planner-week-list')));
          await tester.pumpAndSettle();
        }
        final target = tester.getRect(card('b'));
        var gesture = await hold(tester, 'a');
        await gesture.moveTo(
          grid
              ? Offset(target.right - 8, target.center.dy)
              : Offset(target.center.dx, target.bottom - 8),
        );
        await tester.pump();
        expect(find.byKey(const Key('planner-week-insertion')), findsOneWidget);
        expect(repo.writes, isEmpty);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(order(cubit, items), ['b', 'a', 'c', 'd']);
        expect(repo.writes, hasLength(1));
        expect(items.map((e) => e.toJson()).toList(), snapshot);
        gesture = await hold(tester, 'b');
        final end = tester.getRect(card('d'));
        await gesture.moveTo(Offset(end.right - 5, end.bottom - 5));
        await tester.pump();
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(order(cubit, items), ['b', 'a', 'c', 'd']);
        expect(repo.writes, hasLength(1));
        expect(find.byKey(const Key('planner-week-insertion')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'tap, checkbox and remove are independent of drag; cross-day drop is rejected',
    (tester) async {
      final repo = MemoryWeekOrders();
      final cubit = PlannerWeekOrderCubit(repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      final items = [
        weekItem('a'),
        weekItem('b'),
        weekItem('next', day: DateTime(2026, 11, 24)),
      ];
      final edited = <String>[], toggled = <String>[], removed = <String>[];
      await showWeek(
        tester,
        cubit,
        items,
        edit: (e) => edited.add(e.id),
        toggle: (e) => toggled.add(e.id),
        remove: (e) => removed.add(e.id),
      );
      await tester.tap(body('a'));
      await tester.tap(find.byKey(const ValueKey('planner-week-check-a')));
      await tester.tap(find.byKey(const ValueKey('planner-week-remove-a')));
      await tester.longPress(
        find.byKey(const ValueKey('planner-week-check-b')),
      );
      await tester.longPress(
        find.byKey(const ValueKey('planner-week-remove-b')),
      );
      await tester.pumpAndSettle();
      expect(edited, ['a']);
      expect(toggled, ['a', 'b']);
      expect(removed, ['a']);
      expect(find.byKey(const Key('planner-week-insertion')), findsNothing);
      final gesture = await hold(tester, 'a');
      await gesture.moveTo(tester.getCenter(card('next')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repo.writes, isEmpty);
      expect(order(cubit, items), ['a', 'b']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('screen reader can reorder using hidden custom actions', (
    tester,
  ) async {
    final repo = MemoryWeekOrders();
    final cubit = PlannerWeekOrderCubit(repo);
    addTearDown(cubit.close);
    await cubit.initialize();
    final items = [weekItem('a'), weekItem('b')];
    await showWeek(tester, cubit, items);
    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('planner-week-semantics-a')),
    );
    final actions = semantics.properties.customSemanticsActions!;
    expect(actions.keys.single.label, 'Переместить ниже');
    actions.values.single();
    await tester.pumpAndSettle();
    expect(order(cubit, items), ['b', 'a']);
    expect(find.byTooltip('Переместить ниже'), findsNothing);
  });
  testWidgets(
    'vertical scrolling and edge autoscroll work; releasing outside does not write',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = MemoryWeekOrders();
      final cubit = PlannerWeekOrderCubit(repo);
      addTearDown(cubit.close);
      await cubit.initialize();
      final items = [for (var i = 0; i < 24; i++) weekItem('task-$i')];
      await showWeek(tester, cubit, items);
      final list = tester.widget<ListView>(
        find.byKey(const Key('planner-week-view')),
      );
      await tester.drag(
        find.byKey(const Key('planner-week-view')),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(list.controller!.offset, greaterThan(0));
      list.controller!.jumpTo(0);
      await tester.pump();
      final gesture = await hold(tester, 'task-0');
      await gesture.moveTo(const Offset(180, 575));
      await tester.pump(const Duration(milliseconds: 600));
      expect(list.controller!.offset, greaterThan(0));
      expect(repo.writes, isEmpty);
      await gesture.moveTo(const Offset(450, 575));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Kazakh custom actions work with large text and keep user titles intact',
    (tester) async {
      await tester.runAsync(AppTranslations.load);
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = MemoryWeekOrders();
      final cubit = PlannerWeekOrderCubit(repository);
      addTearDown(cubit.close);
      await cubit.initialize();
      final items = [
        weekItem('Название проекта'),
        weekItem('Другой заголовок'),
      ];
      await showWeek(
        tester,
        cubit,
        items,
        locale: 'kk',
        dark: true,
        textScale: 1.5,
      );
      final actions = tester
          .widget<Semantics>(
            find.byKey(
              const ValueKey('planner-week-semantics-Название проекта'),
            ),
          )
          .properties
          .customSemanticsActions!;
      expect(actions.keys.single.label, 'Төмен жылжыту');
      expect(find.text('Название проекта'), findsOneWidget);
      actions.values.single();
      await tester.pumpAndSettle();
      expect(order(cubit, items), ['Другой заголовок', 'Название проекта']);
      expect(tester.takeException(), isNull);
    },
  );
}
