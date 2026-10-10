import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_inbox_composer.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/inbox/presentation/cubit/inbox_cubit.dart';

void main() {
  testWidgets('creates an inbox task from the dashboard', (tester) async {
    final repository = _FakeInboxRepository();
    final cubit = InboxCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<InboxCubit>.value(
        value: cubit,
        child: const MaterialApp(
          home: Scaffold(body: DashboardInboxComposer()),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('dashboard-inbox-input')),
      'Позвонить клиенту',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('dashboard-inbox-add')));
    await tester.pumpAndSettle();

    expect(repository.createdTitles, <String>['Позвонить клиенту']);
    expect(find.text('Задача добавлена в Инбокс'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dashboard-inbox-input')))
          .controller
          ?.text,
      isEmpty,
    );
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
  }) async {
    return createdTitles
        .map((title) => InboxTaskModel(id: title, title: title))
        .toList(growable: false);
  }
}
