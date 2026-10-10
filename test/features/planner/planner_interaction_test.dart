import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';

void main() {
  testWidgets(
    'renders overlapping tasks and supports completion, creation and calendar views on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final cubit = PlannerCubit(repository);
      addTearDown(cubit.close);
      await cubit.configure('workspace');
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(home: const PlannerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Подготовить презентацию'), findsOneWidget);
      expect(find.text('Проверить бюджет'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('planner-complete-first')));
      await tester.pumpAndSettle();
      expect(cubit.state.items.first.completed, isTrue);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Подготовить презентацию')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('planner-hour-11'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(plannerLocal(repository.lastScheduledAt!).hour, 11);
      await tester.tap(find.byKey(const Key('planner-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Новая задача');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(repository.createdTitle, 'Новая задача');
      await tester.tap(find.text('Неделя'));
      await tester.pumpAndSettle();
      expect(find.text('Пн'), findsOneWidget);
      await tester.tap(find.text('Месяц'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late-night items fit the timeline without layout exceptions', (
    tester,
  ) async {
    final repository = _Repository(late: true);
    final cubit = PlannerCubit(repository);
    addTearDown(cubit.close);
    await cubit.configure('workspace');
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements PlannerRepository {
  _Repository({this.late = false});
  final bool late;
  String? createdTitle;
  DateTime? lastScheduledAt;
  List<PlannerItemModel> get items => [
    PlannerItemModel(
      id: 'first',
      title: 'Подготовить презентацию',
      scheduledAt: plannerInstant(plannerNow(), late ? 23 : 9, late ? 59 : 0),
      durationMinutes: 90,
    ),
    if (!late)
      PlannerItemModel(
        id: 'second',
        title: 'Проверить бюджет',
        scheduledAt: plannerInstant(plannerNow(), 9, 30),
        durationMinutes: 60,
      ),
  ];
  @override
  Future<List<PlannerItemModel>> load(String workspaceId) async => items;
  @override
  Future<void> update(
    PlannerItemModel item, {
    String? title,
    DateTime? scheduledAt,
    int? durationMinutes,
    bool? completed,
  }) async {
    lastScheduledAt = scheduledAt ?? lastScheduledAt;
  }

  @override
  Future<PlannerItemModel> create(
    String workspaceId, {
    required String title,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    createdTitle = title;
    return PlannerItemModel(
      id: 'new',
      title: title,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
    );
  }

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
