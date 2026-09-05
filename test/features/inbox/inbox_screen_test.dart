import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/inbox/presentation/cubit/inbox_cubit.dart';
import 'package:jospar/features/inbox/presentation/screens/inbox_screen.dart';

void main() {
  testWidgets('adds and completes a quick inbox task on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = InboxCubit(_FakeInboxRepository())..load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider<InboxCubit>.value(
        value: cubit,
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Инбокс'), findsOneWidget);
    expect(find.text('Неразобранные'), findsOneWidget);
    expect(find.text('Запишите первую задачу'), findsOneWidget);
    expect(find.text('Непрочитанные'), findsNothing);
    expect(find.text('Упоминания'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('inbox-task-input'))).dy,
      greaterThan(tester.getTopLeft(find.text('Запишите первую задачу')).dy),
    );

    await tester.enterText(
      find.byKey(const Key('inbox-task-input')),
      'Подготовить смету',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox-add-task')));
    await tester.pumpAndSettle();
    expect(find.text('Подготовить смету'), findsOneWidget);
    expect(find.text('Не распределена'), findsOneWidget);

    await tester.tap(find.byTooltip('Завершить задачу'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeInboxRepository implements InboxRepository {
  @override
  Future<List<InboxTaskModel>> getInbox({
    bool archived = true,
    int sort = 1,
  }) async {
    return const <InboxTaskModel>[];
  }
}
