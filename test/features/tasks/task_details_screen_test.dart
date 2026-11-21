import 'package:jospar/features/projects/domain/entities/project_task_model.dart';
import 'package:jospar/features/projects/domain/entities/task_assignee_model.dart';
import 'package:jospar/features/projects/domain/entities/task_epic_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:jospar/core/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/tasks/domain/entities/kanban_column_model.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/domain/repositories/task_details_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:jospar/features/tasks/presentation/screens/task_details_screen.dart';

void main() {
  testWidgets('title tap validates, retries failed save, saves and cancels', (
    tester,
  ) async {
    final repository = _TitleRepository();
    final cubit = TaskDetailsCubit(repository, _ProfileRepository());
    addTearDown(cubit.close);
    await cubit.load('task-1');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-title-edit')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('task-title-field'));
    await tester.enterText(field, '   ');
    await tester.tap(find.byKey(const Key('task-title-save')));
    await tester.pumpAndSettle();
    expect(find.text('Введите название задачи'), findsOneWidget);
    expect(repository.calls, 0);
    await tester.enterText(field, '  Новое название  ');
    repository.fail = true;
    await tester.tap(find.byKey(const Key('task-title-save')));
    await tester.pumpAndSettle();
    expect(cubit.state.task!.title, 'Мобильная задача');
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller!.text,
      '  Новое название  ',
    );
    repository.fail = false;
    await tester.tap(find.byKey(const Key('task-title-save')));
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    expect(cubit.state.task!.title, 'Новое название');
    expect(find.text('Новое название'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-title-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Не сохранять');
    await tester.tap(find.byKey(const Key('task-title-cancel')));
    await tester.pumpAndSettle();
    expect(cubit.state.task!.title, 'Новое название');
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'HTML description is readable in the card and editor without changing source on save',
    (tester) async {
      final repository = _HtmlDetailsRepository();
      final cubit = TaskDetailsCubit(repository, _ProfileRepository());
      addTearDown(cubit.close);
      await cubit.load('task-1');
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TaskDetailsScreen(taskId: 'task-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Школа & библиотека', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(_HtmlDetailsRepository.html), findsNothing);
      await tester.tap(
        find.textContaining('Школа & библиотека', findRichText: true),
      );
      await tester.pumpAndSettle();
      final editor = find.widgetWithText(TextField, 'Школа & библиотека');
      expect(editor, findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(repository.saved, isNull);
      expect(cubit.state.detail.description, _HtmlDetailsRepository.html);
      await tester.tap(
        find.textContaining('Школа & библиотека', findRichText: true),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Школа & библиотека'),
        'Новое описание',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(repository.saved?.description, '<p>Новое описание</p>');
      expect(
        find.textContaining('Новое описание', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discussion places own messages right and others left by user id',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = TaskDetailsCubit(
        _DiscussionRepository(),
        _ProfileRepository(),
      );
      addTearDown(cubit.close);
      await cubit.load('task-1');
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TaskDetailsScreen(taskId: 'task-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('comment-alignment-own')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<Align>(find.byKey(const ValueKey('comment-alignment-own')))
            .alignment,
        Alignment.centerRight,
      );
      expect(
        tester
            .widget<Align>(
              find.byKey(const ValueKey('comment-alignment-other')),
            )
            .alignment,
        Alignment.centerLeft,
      );
      expect(
        tester
            .widget<Align>(
              find.byKey(const ValueKey('comment-alignment-unknown')),
            )
            .alignment,
        Alignment.centerLeft,
      );
      expect(find.text('Вы'), findsOneWidget);
      final disclosure = find.byKey(
        const ValueKey('section-disclosure-Обсуждение'),
      );
      final sectionIcon = find.byKey(const ValueKey('section-icon-Обсуждение'));
      final header = find.byKey(const ValueKey('task-section-Обсуждение'));
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(disclosure).dx,
        lessThan(tester.getCenter(sectionIcon).dx),
      );
      expect(
        tester.getCenter(sectionIcon).dx,
        lessThan(tester.getCenter(find.text('Обсуждение')).dx),
      );
      expect(tester.widget<Icon>(disclosure).icon, LucideIcons.chevronDown);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(disclosure).icon, LucideIcons.chevronRight);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(disclosure).icon, LucideIcons.chevronDown);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('creates a named checklist and adds an editable item', (
    tester,
  ) async {
    final cubit = TaskDetailsCubit(_DetailsRepository(), _ProfileRepository());
    addTearDown(cubit.close);
    await cubit.load('task-1');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Добавить чек-лист'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('task-section-Чек-листы')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('section-disclosure-Чек-листы')),
          )
          .icon,
      LucideIcons.chevronRight,
    );
    await tester.tap(find.byTooltip('Добавить чек-лист'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('quick-add-Название чек-листа')),
      'Проверка релиза',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(cubit.state.detail.checklists.last.name, 'Проверка релиза');
    await tester.ensureVisible(find.text('Добавить пункт').last);
    await tester.tap(find.text('Добавить пункт').last);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('quick-add-Текст пункта')),
      'Проверить сборку',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final list = cubit.state.detail.checklists.last;
    expect(list.items.single.text, 'Проверить сборку');
    await cubit.toggleChecklistItem(list.id, list.items.single.id);
    await tester.pumpAndSettle();
    expect(cubit.state.detail.checklists.last.progress, 1);
    await tester.ensureVisible(find.text('Проверить сборку'));
    await tester.tap(find.text('Проверить сборку'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('checklist-item-text')),
      'Проверить релиз',
    );
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(
      cubit.state.detail.checklists.last.items.single.text,
      'Проверить релиз',
    );
    expect(cubit.state.detail.checklists.last.items.single.done, isTrue);
    await tester.ensureVisible(find.byTooltip('Действия пункта').last);
    await tester.tap(find.byTooltip('Действия пункта').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(cubit.state.detail.checklists.last.items, hasLength(1));
    await tester.tap(find.byTooltip('Действия пункта').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(cubit.state.detail.checklists.last.items, isEmpty);
    expect(cubit.state.detail.checklists.last.progress, 0);
    await cubit.deleteChecklist(list.id);
    await tester.pumpAndSettle();
    expect(
      cubit.state.detail.checklists.any((value) => value.id == list.id),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'checklist changes preserve other detail and roll back failed saves',
    () async {
      final repository = _ChecklistRepository();
      final cubit = TaskDetailsCubit(repository, _ProfileRepository());
      addTearDown(cubit.close);
      await cubit.load('task-1');
      final original = cubit.state.detail;
      await cubit.addChecklist(name: 'Второй');
      final id = cubit.state.detail.checklists.last.id;
      await cubit.modifyChecklist(
        id,
        (list) => list.copyWith(
          sections: const [
            TaskChecklistSectionModel(
              id: 'section',
              name: 'Раздел',
              items: [TaskChecklistItemModel(id: 'nested', text: 'Пункт')],
            ),
          ],
        ),
      );
      await cubit.toggleChecklistItem(id, 'nested');
      expect(cubit.state.detail.checklists.last.completed, 1);
      await cubit.moveChecklist(id, -1);
      expect(cubit.state.detail.checklists.first.id, id);
      await cubit.modifyChecklist(
        id,
        (list) => list.copyWith(name: 'Изменён', sections: []),
      );
      expect(cubit.state.detail.checklists.first.toJson()['sections'], isEmpty);
      expect(cubit.state.detail.comments, original.comments);
      expect(cubit.state.detail.description, original.description);
      final beforeFailure = cubit.state.detail;
      repository.fail = true;
      await cubit.deleteChecklist(id);
      expect(cubit.state.detail, beforeFailure);
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.actionErrorMessage, isNotNull);
      repository.fail = false;
      await cubit.deleteChecklist(id);
      expect(cubit.state.detail.checklists.length, original.checklists.length);
    },
  );

  testWidgets('shows exact estimate and red overtime for a paused timer', (
    tester,
  ) async {
    final cubit = TaskDetailsCubit(_OvertimeRepository(), _ProfileRepository());
    addTearDown(cubit.close);
    await cubit.load('task-1');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ТАЙМИНГ'));
    expect(find.text('0 ч 1 м'), findsOneWidget);
    expect(find.text('00 ч : 01 м : 13 с'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('+13 с')).style!.color,
      AppColors.error,
    );
    expect(find.text('0.0 ч'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits timing and clears it', (tester) async {
    final repository = _DetailsRepository();
    final cubit = TaskDetailsCubit(repository, _ProfileRepository());
    addTearDown(cubit.close);
    await cubit.load('task-1');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ТАЙМИНГ'));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-timing-minutes')), '-1');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Введите целое число от 0'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('task-timing-minutes')), '30');
    await tester.enterText(find.byKey(const Key('task-timing-hours')), '1');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('1 ч 30 м'), findsOneWidget);
    expect(cubit.state.task!.estimate, 2);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать тайминг'));
    await tester.pumpAndSettle();
    expect(find.text('0 ч'), findsNWidgets(2));
    expect(cubit.state.task!.estimate, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timer starts, ticks, pauses and resets', (tester) async {
    final repository = _DetailsRepository();
    final cubit = TaskDetailsCubit(repository, _ProfileRepository());
    addTearDown(cubit.close);
    await cubit.load('task-1');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('task-timer-toggle')));
    await tester.tap(find.byKey(const Key('task-timer-toggle')));
    await tester.pumpAndSettle();
    expect(repository.lastTimerAction, 'start');
    expect(find.byTooltip('Приостановить таймер'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('task-timer-toggle')));
    await tester.pumpAndSettle();
    expect(repository.lastTimerAction, 'pause');
    expect(find.text('00 ч : 00 м : 03 с'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-timer-reset')));
    await tester.pumpAndSettle();
    expect(repository.lastTimerAction, 'reset');
    expect(find.text('00 ч : 00 м : 00 с'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits multiple assignees and removes all assignments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final repository = _DetailsRepository();
    final cubit = TaskDetailsCubit(repository, _ProfileRepository());
    addTearDown(cubit.close);
    await cubit.load('task-1');
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Исполнители'));
    await tester.tap(find.text('Исполнители'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 1'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('save-assignees')).hitTestable(),
      findsOneWidget,
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .value,
      isTrue,
    );
    await tester.tap(find.text('Алина'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.savedIds, ['user-1', 'user-2']);
    await tester.tap(find.text('Исполнители'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Снять всех'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.savedIds, isEmpty);
    expect(find.text('Не назначены'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the task detail on a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _DetailsRepository();
    final cubit = TaskDetailsCubit(repository, _ProfileRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<TaskDetailsCubit>.value(
          value: cubit,
          child: const TaskDetailsScreen(taskId: 'task-1'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загрузка задачи…'), findsOneWidget);

    await cubit.load('task-1');
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('OPB-42'), findsOneWidget);
    expect(find.text('Мобильная задача'), findsOneWidget);
    expect(find.text('РЕСУРС'), findsOneWidget);
    expect(find.byTooltip('История группы ресурсов'), findsOneWidget);
    expect(find.byTooltip('Добавить ресурс'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('task-section-add-РЕСУРС')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.scrollUntilVisible(
      find.text('Чек-листы'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Чек-листы'), findsOneWidget);
    final budgetPosition = tester.getTopLeft(find.text('Бюджет'));
    final materialsPosition = tester.getTopLeft(find.text('Материалы'));
    expect(materialsPosition.dy, closeTo(budgetPosition.dy, 24));
    expect(materialsPosition.dx, greaterThan(budgetPosition.dx));
    final gridToggle = find.byTooltip('Файлы сеткой');
    await tester.scrollUntilVisible(
      gridToggle,
      350,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(gridToggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-files-grid')), findsOneWidget);
    await tester.ensureVisible(find.text('История'));
    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Файлы сеткой'), findsNothing);
    expect(find.byTooltip('Файлы списком'), findsNothing);
    await tester.tap(find.text('Файлы'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-files-grid')), findsOneWidget);
    expect(
      tester.getCenter(gridToggle).dx,
      greaterThan(tester.getCenter(find.text('История')).dx),
    );
    expect(tester.takeException(), isNull);
  });
}

class _DetailsRepository
    implements
        TaskDetailsRepository,
        TaskAssigneesRepository,
        TaskTimingRepository,
        TaskTimerRepository {
  @override
  Future<TaskDetailsPayload> updateEstimate(
    String taskId,
    int minutes, {
    TaskDetailModel? detail,
  }) async => payload.copyWith(
    task: payload.task.copyWith(estimate: (minutes / 60).ceilToDouble()),
    detail: (detail ?? payload.detail).copyWith(estimateMinutes: minutes),
  );
  String? lastTimerAction;
  @override
  Future<TaskDetailsPayload> timerAction(String taskId, String action) async {
    lastTimerAction = action;
    return payload.copyWith(
      task: payload.task.copyWith(
        timerStartedAt: action == 'start' ? DateTime.now() : null,
        timerElapsedMs: action == 'pause' ? 3000 : 0,
      ),
    );
  }

  List<String> savedIds = [];
  @override
  Future<List<TaskAssigneeModel>> getAssigneeCandidates(
    String projectId,
  ) async => const [
    TaskAssigneeModel(userId: 'user-1', name: 'Данияр Исаев'),
    TaskAssigneeModel(userId: 'user-2', name: 'Алина'),
  ];
  @override
  Future<TaskDetailsPayload> updateAssignees(
    String taskId,
    List<String> userIds,
  ) async {
    savedIds = userIds;
    return payload.copyWith(
      task: payload.task.copyWith(
        assignees: (await getAssigneeCandidates(
          'project-1',
        )).where((user) => userIds.contains(user.userId)).toList(),
      ),
    );
  }

  final TaskDetailsPayload payload = TaskDetailsPayload(
    task: const ProjectTaskModel(
      id: 'task-1',
      displayId: 'OPB-42',
      title: 'Мобильная задача',
      projectId: 'project-1',
      status: 'PROGRESS',
      progress: 35,
      assignees: <TaskAssigneeModel>[
        TaskAssigneeModel(userId: 'user-1', name: 'Данияр Исаев'),
      ],
      epics: <TaskEpicModel>[TaskEpicModel(id: 'epic-1', name: 'Архитектура')],
    ),
    detail: const TaskDetailModel(
      description: 'Описание задачи',
      checklists: <TaskChecklistModel>[
        TaskChecklistModel(
          id: 'checklist-1',
          name: 'Проверка',
          items: <TaskChecklistItemModel>[
            TaskChecklistItemModel(id: 'item-1', text: 'Первый пункт'),
          ],
        ),
      ],
      comments: <TaskCommentModel>[
        TaskCommentModel(
          id: 'comment-1',
          author: 'Данияр Исаев',
          text: 'Комментарий',
        ),
      ],
    ),
    resources: const <TaskResourceModel>[
      TaskResourceModel(
        id: 'resource-1',
        name: 'Бюджет',
        planValue: 1000,
        factValue: 500,
      ),
      TaskResourceModel(
        id: 'resource-2',
        order: 1,
        name: 'Материалы',
        planValue: 300,
        factValue: 120,
      ),
    ],
  );

  @override
  Future<TaskDetailsPayload> getTask(String taskId) async => payload;

  @override
  Future<List<TaskHistoryEntryModel>> getHistory(String taskId) async {
    return const <TaskHistoryEntryModel>[];
  }

  @override
  Future<List<KanbanColumnModel>> getColumns(String projectId) async {
    return const <KanbanColumnModel>[
      KanbanColumnModel(
        id: 'column-1',
        name: 'Разработка',
        statusMap: 'PROGRESS',
        projectId: 'project-1',
      ),
    ];
  }

  @override
  Future<TaskDetailsPayload> updateDetail(
    String taskId,
    TaskDetailModel detail,
  ) async => payload.copyWith(detail: detail);

  @override
  Future<TaskDetailsPayload> updateEnd(String taskId, DateTime? end) async {
    return payload.copyWith(task: payload.task.copyWith(end: end));
  }

  @override
  Future<TaskDetailsPayload> updateProgress(
    String taskId,
    int progress, {
    String? status,
  }) async {
    return payload.copyWith(
      task: payload.task.copyWith(
        progress: progress.toDouble(),
        status: status,
      ),
    );
  }
}

class _DiscussionRepository extends _DetailsRepository {
  @override
  Future<TaskDetailsPayload> getTask(String taskId) async => payload.copyWith(
    detail: payload.detail.copyWith(
      comments: const [
        TaskCommentModel(
          id: 'own',
          authorId: 'user-1',
          author: 'Данияр Исаев',
          text: 'Моё сообщение',
        ),
        TaskCommentModel(
          id: 'other',
          authorId: 'user-2',
          author: 'Алина',
          text:
              'Ответ другого участника, который может занимать несколько строк на узком экране',
        ),
        TaskCommentModel(
          id: 'unknown',
          author: 'Данияр Исаев',
          text: 'Имя совпадает, но ID неизвестен',
        ),
      ],
    ),
  );
}

class _ChecklistRepository extends _DetailsRepository {
  bool fail = false;
  @override
  Future<TaskDetailsPayload> updateDetail(
    String taskId,
    TaskDetailModel detail,
  ) async {
    if (fail) throw const TaskDetailsException('Нет подключения');
    return payload.copyWith(detail: detail);
  }
}

class _OvertimeRepository extends _DetailsRepository {
  @override
  Future<TaskDetailsPayload> getTask(String taskId) async => payload.copyWith(
    task: payload.task.copyWith(estimate: 1, timerElapsedMs: 73000),
    detail: payload.detail.copyWith(estimateMinutes: 1),
  );
}

class _ProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) async =>
      (await getCurrentUser()).copyWith(avatarUrl: avatarUrl);

  @override
  Future<UserProfile> getCurrentUser() async {
    return const UserProfile(
      id: 'user-1',
      name: 'Данияр Исаев',
      email: 'user@example.test',
    );
  }
}

class _HtmlDetailsRepository extends _DetailsRepository {
  static const html = '<p>Школа &amp; <strong>библиотека</strong></p>';
  TaskDetailModel? saved;
  @override
  Future<TaskDetailsPayload> getTask(String taskId) async =>
      payload.copyWith(detail: payload.detail.copyWith(description: html));
  @override
  Future<TaskDetailsPayload> updateDetail(
    String taskId,
    TaskDetailModel detail,
  ) async {
    saved = detail;
    return payload.copyWith(detail: detail);
  }
}

class _TitleRepository extends _DetailsRepository
    implements TaskTitleRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<TaskDetailsPayload> updateTitle(String taskId, String title) async {
    calls++;
    if (fail) throw const TaskDetailsException('Ошибка сервера');
    return payload.copyWith(task: payload.task.copyWith(title: title));
  }
}
