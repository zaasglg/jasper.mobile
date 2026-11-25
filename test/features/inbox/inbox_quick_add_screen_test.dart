import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/inbox/domain/entities/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/inbox/presentation/cubit/inbox_cubit.dart';
import 'package:jospar/features/inbox/presentation/screens/inbox_quick_add_screen.dart';

void main() {
  testWidgets('overlay closes after successful save', (tester) async {
    final repository = _FakeInboxRepository();
    final cubit = InboxCubit(repository);
    addTearDown(cubit.close);
    var closed = false;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: InboxQuickAddScreen(
            overlay: true,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Из виджета');
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox-quick-add-submit')));
    await tester.pumpAndSettle();
    expect(repository.createdTitles, ['Из виджета']);
    expect(closed, isTrue);
  });
  testWidgets('quick add creates an inbox task and stays ready for another', (
    tester,
  ) async {
    final repository = _FakeInboxRepository();
    final cubit = InboxCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<InboxCubit>.value(
        value: cubit,
        child: const MaterialApp(home: InboxQuickAddScreen()),
      ),
    );
    await tester.pump();

    final input = find.byKey(const Key('inbox-quick-add-input'));
    expect(tester.widget<TextField>(input).autofocus, isTrue);

    await tester.enterText(input, 'Позвонить клиенту');
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox-quick-add-submit')));
    await tester.pumpAndSettle();

    expect(repository.createdTitles, <String>['Позвонить клиенту']);
    expect(find.text('Задача добавлена в Инбокс'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller?.text, isEmpty);
  });
}

class _FakeInboxRepository implements InboxRepository {
  final List<String> createdTitles = <String>[];

  @override
  Future<void> completeInboxTask({required String id}) async {}

  @override
  Future<void> createInbox({required String title}) async {
    createdTitles.add(title);
  }

  @override
  Future<List<InboxTaskModel>> getInbox({
    bool archived = true,
    int sort = 1,
  }) async => createdTitles
      .map((title) => InboxTaskModel(id: title, title: title))
      .toList(growable: false);
}
