import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jospar/core/widgets/app_form_surface.dart';
import 'package:jospar/features/tasks/data/models/task_creation_models.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_creation_cubit.dart';
import 'package:jospar/features/tasks/presentation/screens/task_creation_screen.dart';
import 'task_creation_test.dart' show CreationFakeRepository;

void main() {
  testWidgets(
    'create form selects metadata and uses 8-hour workdays, preserving fields after failure',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = CreationFakeRepository();
      final cubit = TaskCreationCubit(repository);
      await cubit.initialize(workspaceId: 'w');
      addTearDown(cubit.close);
      TaskCreationResult? created;
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async => created = await context
                    .push<TaskCreationResult>('/tasks/new'),
                child: const Text('Создать'),
              ),
            ),
          ),
          GoRoute(
            path: '/tasks/new',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const TaskCreationScreen(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('create-task-submit'));
      expect(tester.widget<AppFormButton>(submit).onPressed, null);
      await tester.enterText(
        find.byKey(const Key('create-task-title')),
        'Согласовать смету',
      );
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('create-task-days')),
        300,
        scrollable: scroll,
      );
      await tester.enterText(find.byKey(const Key('create-task-days')), '1');
      await tester.enterText(find.byKey(const Key('create-task-hours')), '2');
      await tester.enterText(
        find.byKey(const Key('create-task-minutes')),
        '30',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('create-task-members')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-task-members')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Данияр'));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.assigneeIds, ['v']);
      expect(cubit.state.draft.estimateMinutes, 630);
      repository.fail = true;
      await tester.tap(
        find.descendant(of: submit, matching: find.byType(FilledButton)).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Нет прав на создание'), findsOneWidget);
      expect(cubit.state.draft.title, 'Согласовать смету');
      expect(cubit.state.draft.estimateMinutes, 630);
      repository.fail = false;
      await tester.tap(
        find.descendant(of: submit, matching: find.byType(FilledButton)).first,
      );
      await tester.pumpAndSettle();
      expect(created?.task.title, 'Согласовать смету');
      expect(repository.requests.last.estimateMinutes, 630);
      expect(repository.requests.last.assigneeIds, ['v']);
      expect(repository.requests.last.projectId, 'p');
      expect(repository.requests.last.workspaceId, 'w');
      expect(tester.takeException(), isNull);
    },
  );
}
