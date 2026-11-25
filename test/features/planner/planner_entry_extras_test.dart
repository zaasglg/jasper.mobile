import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/data/models/planner_item_model.dart';
import 'package:jospar/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:jospar/features/planner/domain/utils/planner_dates.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_cubit.dart';
import 'package:jospar/features/planner/presentation/cubit/planner_state.dart';
import 'package:jospar/features/planner/presentation/screens/planner_screen.dart';
import 'package:jospar/features/planner/presentation/widgets/planner_entry_extras.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'planner_test_app.dart';

class Api {
  Api() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'PATCH') {
            writes.add(request);
            if (fail) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: request, statusCode: 403),
                ),
              );
              return;
            }
            final changes = Map<String, dynamic>.from(request.data as Map);
            if (changes.containsKey('checklists')) {
              // Mirror PlannerCheckItemDto: omitted is valid, null is not.
              for (final list in changes['checklists'] as List) {
                final entries = [
                  ...list['items'] as List,
                  for (final section in list['sections'] as List? ?? [])
                    ...section['items'] as List,
                ];
                if (entries.any(
                  (entry) =>
                      (entry as Map).containsKey('dueDate') &&
                      entry['dueDate'] is! String,
                )) {
                  handler.reject(
                    DioException(
                      requestOptions: request,
                      type: DioExceptionType.badResponse,
                      response: Response(
                        requestOptions: request,
                        statusCode: 400,
                      ),
                    ),
                  );
                  return;
                }
              }
              item['detail'] = {
                ...item['detail'] as Map,
                'checklists': changes.remove('checklists'),
              };
            }
            item.addAll(changes);
          }
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: request.method == 'GET' ? [item] : item,
            ),
          );
        },
      ),
    );
  }
  final dio = Dio();
  final writes = <RequestOptions>[];
  bool fail = false;
  final item = <String, dynamic>{
    'id': 'slot',
    'title': 'Личная запись',
    'scheduledAt': plannerInstant(plannerNow(), 9, 0).toIso8601String(),
    'creator': {'name': 'Автор из API'},
    'icon': null,
    'reminderMinutes': 15,
    'detail': <String, dynamic>{'note': 'preserve', 'checklists': []},
  };
  PlannerRepositoryImpl get repository => PlannerRepositoryImpl(dio);
}

Future<void> panel(WidgetTester tester, PlannerCubit cubit) =>
    tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocBuilder<PlannerCubit, PlannerState>(
                builder: (context, state) {
                  final item = state.items.single;
                  return Column(
                    children: [
                      PlannerIconSelector(
                        item: item,
                        enabled: !state.busyIds.contains(item.id),
                      ),
                      PlannerChecklistsPanel(
                        item: item,
                        enabled: !state.busyIds.contains(item.id),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  test(
    'extras use the web PATCH payload and preserve other detail fields',
    () async {
      final api = Api();
      addTearDown(api.dio.close);
      final repository = api.repository;
      await repository.updateExtras('slot/one', updateIcon: true, icon: null);
      expect(api.writes.last.path, 'project-planner/items/slot%2Fone');
      expect(api.writes.last.data, {'icon': null});
      const checklist = TaskChecklistModel(
        id: 'list',
        name: 'Проверка',
        items: [TaskChecklistItemModel(id: 'one', text: 'Проверить')],
      );
      await repository.updateExtras('slot', checklists: [checklist]);
      expect((api.writes.last.data as Map).containsKey('icon'), isFalse);
      final parsed = (await repository.load()).single;
      expect(parsed.checklists.single.items.single.text, 'Проверить');
      expect(parsed.detail['note'], 'preserve');
      expect(parsed.creatorName, 'Автор из API');
      expect(parsed.reminderMinutes, 15);
      await repository.update(
        parsed,
        scheduledAt: plannerInstant(plannerNow(), 14, 30),
        reminderMinutes: 30,
      );
      expect((api.writes.last.data as Map)['reminderMinutes'], 30);
      expect(
        PlannerItemModel.fromJson(parsed.toJson()).checklists.single.total,
        1,
      );
    },
  );

  test(
    'planner checklist DTO omits absent dates at every nesting level',
    () async {
      final api = Api();
      addTearDown(api.dio.close);
      final due = DateTime.utc(2026, 11, 24);
      await api.repository.updateExtras(
        'slot',
        checklists: [
          TaskChecklistModel(
            id: 'list',
            name: 'Проверка',
            items: const [
              TaskChecklistItemModel(id: 'plain', text: 'Без срока'),
            ],
            sections: [
              TaskChecklistSectionModel(
                id: 'section',
                name: 'Раздел',
                items: [
                  const TaskChecklistItemModel(id: 'nested', text: 'Без срока'),
                  TaskChecklistItemModel(
                    id: 'dated',
                    text: 'Со сроком',
                    done: true,
                    dueDate: due,
                    assigneeIds: const ['user'],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final payload = api.writes.single.data as Map;
      final list = (payload['checklists'] as List).single as Map;
      expect((list['items'] as List).single, {
        'id': 'plain',
        'text': 'Без срока',
        'done': false,
        'assigneeIds': [],
      });
      final items =
          (((list['sections'] as List).single as Map)['items'] as List);
      expect((items.first as Map).containsKey('dueDate'), isFalse);
      expect(items.last, {
        'id': 'dated',
        'text': 'Со сроком',
        'done': true,
        'dueDate': due.toIso8601String(),
        'assigneeIds': ['user'],
      });
    },
  );

  test('failed extras restore previous icon and checklist state', () async {
    final api = Api()..fail = true;
    addTearDown(api.dio.close);
    final cubit = PlannerCubit(api.repository);
    addTearDown(cubit.close);
    await cubit.refresh();
    final before = cubit.state.items.single;
    expect(
      await cubit.updateExtras(before, updateIcon: true, icon: 'home'),
      isFalse,
    );
    expect(cubit.state.items.single, before);
    expect(cubit.state.actionError, isNotNull);
    expect(cubit.state.busyIds, isEmpty);
  });

  test(
    'planner checklists cannot mutate linked project or inbox tasks',
    () async {
      final api = Api();
      api.item['taskId'] = 'source-task';
      addTearDown(api.dio.close);
      final cubit = PlannerCubit(api.repository);
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(
        await cubit.updateExtras(cubit.state.items.single, checklists: []),
        isFalse,
      );
      expect(api.writes, isEmpty);
    },
  );

  testWidgets('icon can be chosen and returned to Auto', (tester) async {
    final api = Api();
    final cubit = PlannerCubit(api.repository);
    addTearDown(cubit.close);
    addTearDown(api.dio.close);
    await tester.runAsync(cubit.refresh);
    await panel(tester, cubit);
    await tester.tap(find.byKey(const Key('planner-icon-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planner-icon-home')));
    await tester.pumpAndSettle();
    expect(api.item['icon'], 'home');
    expect(find.text('Дом'), findsOneWidget);
    await tester.tap(find.byKey(const Key('planner-icon-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-icon-auto')));
    await tester.pumpAndSettle();
    expect(api.item['icon'], isNull);
    expect(find.text('Авто'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a checklist, adds an item and saves completion', (
    tester,
  ) async {
    final api = Api();
    final cubit = PlannerCubit(api.repository);
    addTearDown(cubit.close);
    addTearDown(api.dio.close);
    await tester.runAsync(cubit.refresh);
    await panel(tester, cubit);
    await tester.tap(find.byKey(const Key('planner-add-checklist')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quick-add-Название чек-листа')),
      'Перед запуском',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(cubit.state.items.single.checklists.single.name, 'Перед запуском');
    await tester.tap(find.text('Добавить пункт'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quick-add-Текст пункта')),
      'Проверить данные',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final id = cubit.state.items.single.checklists.single.items.single.id;
    await tester.tap(find.byKey(ValueKey('planner-check-$id')));
    await tester.pumpAndSettle();
    expect(
      cubit.state.items.single.checklists.single.items.single.done,
      isTrue,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('planner-checklist-count')))
          .data,
      '1/1',
    );
    expect(
      (await tester.runAsync(
        api.repository.load,
      ))!.single.checklists.single.completed,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('checking an item preserves the surrounding editor widgets', (
    tester,
  ) async {
    final api = Api();
    api.item['detail'] = {
      'checklists': [
        {
          'id': 'list',
          'name': 'Список',
          'items': [
            {'id': 'one', 'text': 'Пункт', 'done': false},
          ],
        },
      ],
    };
    final cubit = PlannerCubit(api.repository);
    addTearDown(cubit.close);
    addTearDown(api.dio.close);
    await tester.pumpWidget(
      PlannerTestApp(
        child: BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: PlannerScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planner-open-slot')));
    await tester.pumpAndSettle();
    final title = tester.widget(find.byKey(const Key('planner-editor-title')));
    final save = tester.widget(find.byKey(const Key('planner-editor-save')));
    final complete = tester.widget(
      find.byKey(const Key('planner-entry-complete')),
    );
    final icon = tester.widget(find.byType(PlannerIconSelector));
    await tester.ensureVisible(find.byKey(const ValueKey('planner-check-one')));
    await tester.tap(find.byKey(const ValueKey('planner-check-one')));
    await tester.pumpAndSettle();
    expect(cubit.state.items.single.checklists.single.completed, 1);
    expect(
      identical(
        tester.widget(find.byKey(const Key('planner-editor-title'))),
        title,
      ),
      isTrue,
    );
    expect(
      identical(
        tester.widget(find.byKey(const Key('planner-editor-save'))),
        save,
      ),
      isTrue,
    );
    expect(
      identical(
        tester.widget(find.byKey(const Key('planner-entry-complete'))),
        complete,
      ),
      isTrue,
    );
    expect(
      identical(tester.widget(find.byType(PlannerIconSelector)), icon),
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const Key('planner-entry-complete')));
    await tester.tap(find.byKey(const Key('planner-entry-complete')));
    await tester.pumpAndSettle();
    expect(cubit.state.items.single.completed, isTrue);
    expect(cubit.state.items.single.checklists.single.completed, 1);
    expect(
      identical(
        tester.widget(find.byKey(const Key('planner-editor-title'))),
        title,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'detail editor shows source and creator and saves reminder with schedule',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = Api();
      final cubit = PlannerCubit(api.repository);
      addTearDown(cubit.close);
      addTearDown(api.dio.close);
      await tester.pumpWidget(
        PlannerTestApp(
          child: BlocProvider.value(
            value: cubit,
            child: const MaterialApp(home: PlannerScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('planner-open-slot')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Автор из API', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(const Key('planner-icon-selector')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('planner-entry-reminder')),
      );
      await tester.tap(find.byKey(const Key('planner-entry-reminder')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('За 30 минут').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('planner-editor-save')));
      await tester.tap(find.byKey(const Key('planner-editor-save')));
      await tester.pumpAndSettle();
      expect(api.item['reminderMinutes'], 30);
      expect(find.byKey(const Key('planner-editor-title')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('planner-open-slot')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('planner-editor-title')),
        'Черновик после ошибки',
      );
      api.fail = true;
      await tester.ensureVisible(find.byKey(const Key('planner-editor-save')));
      await tester.tap(find.byKey(const Key('planner-editor-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-entry-save-error')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('planner-editor-title')))
            .controller!
            .text,
        'Черновик после ошибки',
      );
      api.fail = false;
      await tester.ensureVisible(find.byKey(const Key('planner-editor-save')));
      await tester.tap(find.byKey(const Key('planner-editor-save')));
      await tester.pumpAndSettle();
      expect(api.item['title'], 'Черновик после ошибки');

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
