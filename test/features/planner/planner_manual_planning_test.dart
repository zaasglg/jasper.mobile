import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/inbox/data/models/inbox_task_model.dart';
import 'package:jospar/features/inbox/domain/repositories/inbox_repository.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/domain/repositories/planner_repository.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/domain/repositories/my_tasks_repository.dart';

import 'planner_test_app.dart';

const _projectTitle = 'Шифрование звонков из проекта';
const _inboxTitle = 'Личное дело из Инбокса';

class _ProjectTasks implements MyTasksRepository {
  int loads = 0;

  @override
  Future<List<ProjectTaskModel>> getTasks({
    required String assigneeId,
    List<String> projectIds = const [],
  }) async {
    loads++;
    return [
      ProjectTaskModel(
        id: 'project-task',
        projectId: 'project',
        displayId: 'JO-261',
        title: _projectTitle,
        status: 'TODO',
        end: plannerInstant(plannerNow(), 12, 0),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile implements ProfileRepository {
  int loads = 0;

  @override
  Future<UserProfile> getCurrentUser() async {
    loads++;
    return const UserProfile(
      id: 'user',
      name: 'Пользователь',
      email: 'user@example.com',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Inbox implements InboxRepository {
  int loads = 0;

  @override
  Future<List<InboxTaskModel>> getInbox({
    bool archived = true,
    int sort = 1,
  }) async {
    loads++;
    return [const InboxTaskModel(id: 'inbox-task', title: _inboxTitle)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Planner implements PlannerRepository {
  final items = <PlannerItemModel>[];
  int loads = 0;
  int writes = 0;

  @override
  Future<List<PlannerItemModel>> load() async {
    loads++;
    return [...items];
  }

  @override
  Future<void> addTask({
    String? projectId,
    String? taskId,
    String? inboxTaskId,
    required DateTime? scheduledAt,
    DateTime? plannedDate,
    required int durationMinutes,
  }) async {
    writes++;
    items.add(
      PlannerItemModel(
        id: 'manual-slot',
        projectId: projectId,
        taskId: taskId,
        inboxTaskId: inboxTaskId,
        title: taskId == null ? _inboxTitle : _projectTitle,
        scheduledAt: scheduledAt,
        plannedDate: plannedDate,
        durationMinutes: durationMinutes,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _show(
  WidgetTester tester,
  _Planner planner,
  _ProjectTasks tasks,
  _Profile profile,
  _Inbox inbox,
) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  sl.registerSingleton<MyTasksRepository>(tasks);
  sl.registerSingleton<ProfileRepository>(profile);
  sl.registerSingleton<InboxRepository>(inbox);
  addTearDown(() async {
    await sl.unregister<MyTasksRepository>();
    await sl.unregister<ProfileRepository>();
    await sl.unregister<InboxRepository>();
  });
  final cubit = PlannerCubit(planner);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    PlannerTestApp(
      child: BlocProvider.value(
        value: cubit,
        child: MaterialApp(theme: AppTheme.light, home: const PlannerScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'opening, changing views and refreshing never import task deadlines',
    (tester) async {
      final planner = _Planner();
      final tasks = _ProjectTasks();
      final profile = _Profile();
      final inbox = _Inbox();
      await _show(tester, planner, tasks, profile, inbox);
      expect(find.byKey(const Key('planner-empty-title')), findsOneWidget);
      for (final mode in ['День', 'Неделя', 'Месяц']) {
        await tester.tap(find.text(mode));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byKey(const Key('planner-pull-to-refresh')),
              matching: find.byType(Scrollable),
            )
            .first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pump();
        final previousLoads = planner.loads;
        await tester.drag(scrollable, const Offset(0, 400));
        await tester.pumpAndSettle();
        expect(planner.loads, previousLoads + 1);
        expect(tasks.loads, 0, reason: mode);
        expect(profile.loads, 0, reason: mode);
        expect(inbox.loads, 0, reason: mode);
        expect(find.textContaining('JO-261'), findsNothing);
        expect(find.text(_projectTitle), findsNothing);
        expect(find.textContaining('Сроки:'), findsNothing);
        expect(find.text('Нет задач со сроком'), findsNothing);
        expect(find.byIcon(Icons.flag_outlined), findsNothing);
      }
      expect(planner.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final project in [true, false]) {
    testWidgets(
      'task sources load only on explicit selection and save after confirmation (project=$project)',
      (tester) async {
        final planner = _Planner();
        final tasks = _ProjectTasks();
        final profile = _Profile();
        final inbox = _Inbox();
        await _show(tester, planner, tasks, profile, inbox);
        await tester.tap(find.byKey(const Key('planner-add')));
        await tester.pumpAndSettle();
        expect(tasks.loads, 0);
        expect(inbox.loads, 0);
        await tester.tap(find.text('Из проекта или Инбокса'));
        await tester.pumpAndSettle();
        expect(tasks.loads, 1);
        expect(profile.loads, 1);
        expect(inbox.loads, 1);
        expect(find.text(_projectTitle), findsOneWidget);
        expect(find.text(_inboxTitle), findsOneWidget);
        expect(planner.writes, 0);
        await tester.tap(find.text(project ? _projectTitle : _inboxTitle));
        await tester.pumpAndSettle();
        expect(planner.writes, 0);
        await tester.ensureVisible(find.text('Сохранить'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        expect(planner.writes, 1);
        expect(planner.items.single.taskId, project ? 'project-task' : null);
        expect(planner.items.single.inboxTaskId, project ? null : 'inbox-task');
        expect(
          find.byKey(const ValueKey('planner-unscheduled-manual-slot')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.flag_outlined), findsNothing);
        expect(tasks.loads, 1);
        expect(inbox.loads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
