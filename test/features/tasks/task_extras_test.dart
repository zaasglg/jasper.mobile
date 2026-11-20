import 'dart:async';
import 'package:jospar/features/tasks/presentation/widgets/task_extras_sheet.dart';
import 'package:jospar/core/widgets/app_color_picker.dart';
import 'package:jospar/core/theme/task_label_color.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jospar/features/tasks/presentation/widgets/resource_server_tools.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_resource_pairs.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_resource_editor.dart';
import 'package:jospar/features/tasks/data/services/task_file_picker.dart';
import 'package:jospar/core/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/tasks/presentation/screens/task_details_screen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'task_test_app.dart';

void main() {
  test('pair rollback preserves resources created by another user', () async {
    final adapter = _ExtrasAdapter()..failFactWithConcurrentResource = true;
    final cubit = TaskDetailsCubit(
      TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
      _Profile(),
    );
    addTearDown(cubit.close);
    await cubit.load('t');
    expect(await cubit.createResourcePair(), isFalse);
    expect(adapter.resources.map((r) => r['id']), ['other-user']);
    expect(cubit.state.resources.single.id, 'other-user');
  });

  testWidgets(
    'existing labels assign, detach, retain catalog and reopen by scope',
    (tester) async {
      final adapter = _ExtrasAdapter()
        ..catalog = {
          'shared': [
            {'id': 'shared', 'text': 'Работа', 'color': 'var(--label-red)'},
          ],
          'personal': [
            {'id': 'mine', 'text': 'Моя', 'color': '#123456'},
          ],
        };
      final cubit = await _mountExtras(tester, adapter, TaskExtraTab.labels);
      expect(find.text('Чужая метка'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Работа'));
      await tester.pumpAndSettle();
      expect(cubit.state.detail.labels.single.id, 'shared');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Моя'));
      await tester.pumpAndSettle();
      expect(cubit.labelsForScope(true).single.id, 'mine');
      expect(cubit.labelsForScope(false).single.text, 'Работа');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Работа'));
      await tester.pumpAndSettle();
      expect(cubit.state.detail.labels, isEmpty);
      expect((adapter.detail['labelCatalog'] as List).single['text'], 'Работа');
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => cubit.load('t'));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Работа'),
            )
            .value,
        false,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Моя'),
            )
            .value,
        true,
      );
      expect((adapter.detail['personalLabels'] as Map)['other'], [
        {'id': 'private', 'text': 'Чужая метка'},
      ]);
      expect(taskLabelColor('var(--label-red)'), const Color(0xFFE11D48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'label creation validates, preserves failed draft, guards double save and persists color',
    (tester) async {
      final adapter = _ExtrasAdapter()
        ..catalog = {
          'shared': [
            {'id': 'existing', 'text': 'Работа', 'color': '#123456'},
          ],
          'personal': [],
        };
      final cubit = await _mountExtras(tester, adapter, TaskExtraTab.labels);
      await tester.tap(find.text('Добавить метку').first);
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      await tester.enterText(find.byKey(const Key('label_name')), '   ');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Введите название'), findsOneWidget);
      expect(adapter.patches, 0);
      await tester.enterText(find.byKey(const Key('label_name')), '  РАБОТА  ');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.textContaining('уже существует'), findsOneWidget);
      expect(adapter.patches, 0);
      await tester.enterText(find.byKey(const Key('label_name')), '  Новая  ');
      await tester.tap(find.byTooltip('#2563EB'));
      adapter.offline = true;
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('label_name')))
            .controller!
            .text,
        '  Новая  ',
      );
      expect(find.text('Новая метка'), findsOneWidget);
      expect(find.text('Нет подключения к интернету.'), findsWidgets);
      expect(cubit.state.detail.labels, isEmpty);
      adapter.offline = false;
      adapter.patchGate = Completer<void>();
      final before = adapter.patches;
      await tester.tap(find.text('Сохранить'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Сохранение…'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.patches, before + 1);
      adapter.patchGate!.complete();
      await tester.pumpAndSettle();
      expect(cubit.state.detail.labels.single.text, 'Новая');
      expect(cubit.state.detail.labels.single.color, '#2563EB');
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => cubit.load('t'));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Изменить метку').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppColorPicker>(find.byType(AppColorPicker)).value,
        '#2563EB',
      );
      final savedPatches = adapter.patches;
      await tester.enterText(
        find.byKey(const Key('label_name')),
        'Не сохранять',
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(adapter.patches, savedPatches);
      expect(cubit.state.detail.labels.single.text, 'Новая');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'personal creation stays scoped and back returns without saving',
    (tester) async {
      final adapter = _ExtrasAdapter();
      final cubit = await _mountExtras(tester, adapter, TaskExtraTab.labels);
      await tester.tap(find.text('Добавить метку').last);
      await tester.pumpAndSettle();
      expect(find.text('Личная метка'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('label_name')), '  Моё  ');
      await tester.tap(find.byTooltip('#16A34A'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(cubit.labelsForScope(true).single.text, 'Моё');
      expect(cubit.labelsForScope(true).single.color, '#16A34A');
      expect(cubit.state.detail.labels, isEmpty);
      await tester.runAsync(() => cubit.load('t'));
      expect(cubit.labelsForScope(true).single.text, 'Моё');
      expect((adapter.detail['personalLabelCatalog'] as Map)['me'], isNotEmpty);
      await tester.tap(find.text('Добавить метку').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('label_name')), 'Отмена');
      final count = adapter.patches;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('label_name')), findsNothing);
      expect(find.text('Личные метки'), findsOneWidget);
      expect(adapter.patches, count);
    },
  );

  testWidgets(
    'catalog network error retries and short content does not fill screen',
    (tester) async {
      final adapter = _ExtrasAdapter()..failCatalog = true;
      await _mountExtras(tester, adapter, TaskExtraTab.labels);
      expect(find.text('Не удалось загрузить метки.'), findsOneWidget);
      adapter.failCatalog = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Нет меток. Создайте новую.'), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(TaskExtrasSheet)).height,
        lessThan(450),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'epics load for project, retry, support multiple links, rollback and detach after reopen',
    (tester) async {
      final adapter = _ExtrasAdapter()
        ..failEpics = true
        ..epics = [
          {'id': 'e1', 'name': 'Эпик 1'},
          {'id': 'e2', 'name': 'Эпик 2'},
        ];
      final cubit = await _mountExtras(tester, adapter, TaskExtraTab.epics);
      expect(adapter.epicProjectId, 'p');
      adapter.failEpics = false;
      await tester.tap(find.text('Повторить загрузку эпиков'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Эпик 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Эпик 2'));
      await tester.pumpAndSettle();
      expect(cubit.state.task!.epics.map((e) => e.id), ['e1', 'e2']);
      adapter.fail = true;
      await tester.tap(find.text('Эпик 1'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Эпик 1'),
            )
            .value,
        true,
      );
      adapter.fail = false;
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => cubit.load('t'));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      for (final name in ['Эпик 1', 'Эпик 2']) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      expect(adapter.epicIds, isEmpty);
      await tester.runAsync(() => cubit.load('t'));
      expect(cubit.state.task!.epics, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long catalog and creation scroll at large text with keyboard on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final adapter = _ExtrasAdapter()
        ..catalog = {
          'shared': List.generate(
            30,
            (i) => {
              'id': '$i',
              'text': 'Очень длинное название метки проекта номер $i',
              'color': '#123456',
            },
          ),
          'personal': [],
        };
      await _mountExtras(tester, adapter, TaskExtraTab.labels, textScale: 1.8);
      final add = find.byKey(const ValueKey('create_project_label'));
      await tester.scrollUntilVisible(
        add,
        400,
        scrollable: find
            .descendant(
              of: find.byType(TaskExtrasSheet),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 50,
      );
      await tester.pumpAndSettle();
      await tester.tap(add.first);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('label_name')));
      await tester.enterText(
        find.byKey(const Key('label_name')),
        'Длинная метка',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.text('Сохранить')).dy,
        lessThanOrEqualTo(400),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('dates save together using existing task PATCH', () async {
    final adapter = _ExtrasAdapter();
    final repo = TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter);
    await repo.updateDates(
      't',
      DateTime.utc(2026, 11, 13, 9),
      DateTime.utc(2026, 11, 14, 18),
    );
    expect(adapter.lastPath, 'project-tasks/t');
    expect(adapter.lastData, {
      'start': '2026-11-13T09:00:00.000Z',
      'end': '2026-11-14T18:00:00.000Z',
    });
  });
  test(
    'history aligns by minute chronologically and leaves missing side blank',
    () {
      Map<String, Object?> entry(String id, String time) => {
        'id': id,
        'createdAt': '2026-11-13T$time:00Z',
      };
      final rows = alignResourceHistories([
        [entry('p3', '18:20'), entry('p2', '18:14'), entry('p1', '18:14')],
        [entry('f3', '18:28'), entry('f2', '18:25'), entry('f1', '18:14')],
      ]);
      expect(rows.map((r) => r.map((e) => e?['id']).toList()).toList(), [
        ['p1', 'f1'],
        ['p2', null],
        ['p3', null],
        [null, 'f2'],
        [null, 'f3'],
      ]);
    },
  );
  testWidgets(
    'group history shows two tables without tabs on a narrow screen',
    (tester) async {
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = _ExtrasAdapter()),
        _Profile(),
      );
      addTearDown(cubit.close);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showResourcePairHistory(context, cubit, const [
                  TaskResourceModel(id: 'p', name: 'План 2'),
                  TaskResourceModel(id: 'f', name: 'Факт 2', order: 1),
                ]),
                child: const Text('История'),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('История'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('История ресурсов'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(Table), findsNWidgets(2));
      expect(find.byTooltip('Закрыть историю'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Закрыть историю'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'resource group stays compact and renders paired inputs at mobile width',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = _ExtrasAdapter()),
        _Profile(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('resources-preview'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BlocProvider.value(
                  value: cubit,
                  child: const TaskResourcePairs(
                    resources: [
                      TaskResourceModel(
                        id: 'plan',
                        name: 'Планы',
                        planValue: 400,
                      ),
                      TaskResourceModel(id: 'fact', name: 'Факты', order: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Расход 0%'), findsOneWidget);
      expect(find.byTooltip('История группы ресурсов'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_RESOURCE_UI')) {
        await expectLater(
          find.byKey(const Key('resources-preview')),
          matchesGoldenFile(
            '../../..'
            '/.codex/visual/resource-inline-polish/mobile.png',
          ),
        );
      }
    },
  );
  testWidgets('resource values edit inline without opening a dialog', (
    tester,
  ) async {
    final adapter = _ExtrasAdapter();
    final cubit = TaskDetailsCubit(
      TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
      _Profile(),
    );
    addTearDown(cubit.close);
    await tester.runAsync(() => cubit.load('t'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceInlineField(
            resource: const TaskResourceModel(id: 'r', name: 'План'),
            cubit: cubit,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '123,5');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(adapter.lastData, isNull);
    expect(find.text('123.5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test('plus creates plan and fact pair without a shared name', () async {
    final adapter = _ExtrasAdapter();
    final cubit = TaskDetailsCubit(
      TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
      _Profile(),
    );
    addTearDown(cubit.close);
    await cubit.load('t');
    expect(await cubit.createResourcePair(), isTrue);
    expect(cubit.state.resources.map((r) => r.name), ['План', 'Факт']);
    expect(cubit.state.resources.map((r) => r.id).toSet().length, 2);
    expect(
      await cubit.patchResource(cubit.state.resources.first.id, {
        'name': 'Бетон',
      }),
      isTrue,
    );
    expect(cubit.state.resources.map((r) => r.name), ['Бетон', 'Факт']);
    expect(await cubit.deleteResourcePair(cubit.state.resources), isTrue);
    expect(cubit.state.resources, isEmpty);
  });
  test(
    'resource calculator and history use documented API without stale numeric fields',
    () async {
      final adapter = _ExtrasAdapter();
      final repo = TaskDetailsRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      await repo.patchResource('r', {
        'calculation': {'target': 'FACT', 'operation': 'ADD', 'value': '25'},
      });
      expect(adapter.lastPath, 'resources/r');
      expect(adapter.lastData, {
        'calculation': {'target': 'FACT', 'operation': 'ADD', 'value': '25'},
      });
      await repo.patchResource('r', {'name': 'Бетон'});
      expect(adapter.lastData, {'name': 'Бетон'});
      final history = await repo.resourceHistory('r', cursor: 'next');
      expect(adapter.lastPath, 'resources/r/history');
      expect(history['nextCursor'], isNull);
      expect(history['items'], isEmpty);
    },
  );
  test(
    'resource CRUD refreshes state and duplicate receives a new server id',
    () async {
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await cubit.load('t');
      const draft = TaskResourceModel(
        id: '',
        name: 'Бюджет',
        planValue: 500,
        factValue: 300,
      );
      expect(await cubit.saveResource(draft, create: true), isTrue);
      final first = cubit.state.resources.single;
      expect(first.percentage, 60);
      expect(
        await cubit.saveResource(first.copyWith(factValue: 600), create: false),
        isTrue,
      );
      expect(cubit.state.resources.single.percentage, 120);
      expect(
        await cubit.saveResource(
          first.copyWith(id: '', name: '${first.name} — копия'),
          create: true,
        ),
        isTrue,
      );
      expect(cubit.state.resources.length, 2);
      expect(cubit.state.resources.last.id, isNot(first.id));
      expect(await cubit.deleteResource(first.id), isTrue);
      expect(cubit.state.resources.length, 1);
      expect(
        await cubit.saveResource(draft.copyWith(planValue: -1), create: true),
        isFalse,
      );
      expect(cubit.state.resources.length, 1);
    },
  );
  testWidgets(
    'resource editor validates negatives, preserves failed draft and retries on narrow screen',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await tester.runAsync(() => cubit.load('t'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TaskResourceEditor(cubit: cubit)),
        ),
      );
      expect(find.text('0.0'), findsNothing);
      expect(find.text('Использовано: —'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Материал');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.enterText(find.byType(TextFormField).at(2), '3,5');
      await tester.pump();
      expect(find.text('Укажите план для расчёта процента'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '2.5');
      await tester.pump();
      expect(find.text('Использовано: 140% · Перерасход'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '-1');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Введите число от 0'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '500');
      await tester.enterText(find.byType(TextFormField).at(2), '300');
      await tester.pump();
      expect(find.text('Использовано: 60%'), findsOneWidget);
      adapter.fail = true;
      await tester.runAsync(() async {
        await tester.tap(find.text('Сохранить'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Материал'), findsOneWidget);
      expect(
        find.text('Недостаточно прав для изменения ресурсов.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'task menu edits labels through the real detail save flow on a narrow screen',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = _ExtrasAdapter()),
        _Profile(),
      );
      addTearDown(cubit.close);
      await tester.runAsync(() => cubit.load('t'));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider.value(
            value: cubit,
            child: const TaskDetailsScreen(taskId: 't'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Действия задачи'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Метки и личные метки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить метку').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AppDialog), findsNothing);
      await tester.enterText(
        find.byKey(const Key('label_name')),
        'Новая метка',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(cubit.state.detail.labels.single.text, 'Новая метка');
      expect(find.text('Новая метка'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'personal labels are user scoped, preserve other users and roll back errors',
    () async {
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await cubit.load('t');
      expect(
        await cubit.updatePersonalLabels(const [
          TaskLabelModel(id: 'l', text: 'Моя метка'),
        ]),
        true,
      );
      final personal = cubit.state.detail.raw['personalLabels'] as Map;
      expect(personal['other'], [
        {'id': 'private', 'text': 'Чужая метка'},
      ]);
      expect(cubit.state.visibleLabels.map((e) => e.text), ['Моя метка']);
      expect(cubit.state.task!.labelsForUser('me').map((e) => e.text), [
        'Моя метка',
      ]);
      expect(cubit.state.detail.raw['unknown'], {'retained': true});
      adapter.fail = true;
      expect(
        await cubit.updateLabels(const [
          TaskLabelModel(id: 'bad', text: 'Не сохранено'),
        ]),
        false,
      );
      expect(cubit.state.detail.labels, isEmpty);
      expect(cubit.state.detail.raw['personalLabels'], personal);
      expect(cubit.state.isSaving, false);
    },
  );
  testWidgets(
    'task Files section uploads through backend, keeps detail and rolls back rejected upload',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final original = FilePickerPlatform.instance;
      final picker = _Picker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await tester.runAsync(() => cubit.load('t'));
      await tester.pumpWidget(
        TaskTestApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TaskDetailsScreen(taskId: 't'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('task-add-files'));
      await tester.scrollUntilVisible(
        button,
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Файлы').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.detail.files.length, 2);
      final added = cubit.state.detail.files.last;
      expect(added.name, 'report.txt');
      expect(added.dataUrl, 'data:text/plain;base64,SGk=');
      expect(added.size, 2);
      expect(cubit.state.detail.description, 'Описание');
      expect(cubit.state.detail.raw['unknown'], {'retained': true});
      expect(adapter.lastPath, 'project-tasks/t/history');
      expect(adapter.detail['files'], hasLength(2));
      adapter.fail = true;
      ScaffoldMessenger.of(tester.element(button)).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Файлы').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.detail.files.length, 2);
      expect(cubit.state.actionErrorMessage, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'task file picker handles cancellation and refuses oversized streams',
    () async {
      final original = FilePickerPlatform.instance;
      final picker = _Picker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      picker.files = [];
      expect(await TaskFilePicker.pick(), isEmpty);
      picker.files = [_MemoryFile(oversized: true)];
      await expectLater(TaskFilePicker.pick(), throwsA(isA<Exception>()));
    },
  );
  test(
    'files persist alongside existing detail and removal clears only their cover reference',
    () async {
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await cubit.load('t');
      expect(
        await cubit.addFiles(const [
          TaskFileModel(
            id: 'added',
            name: 'test.txt',
            dataUrl: 'data:text/plain;base64,WA==',
          ),
        ]),
        true,
      );
      expect(cubit.state.detail.files.map((e) => e.id), ['cover', 'added']);
      expect(await cubit.removeFile('cover'), true);
      expect(cubit.state.detail.files.single.id, 'added');
      expect(cubit.state.detail.raw['cover'], isNull);
      expect(cubit.state.detail.description, 'Описание');
      expect(cubit.state.detail.raw['personalLabels'], {
        'other': [
          {'id': 'private', 'text': 'Чужая метка'},
        ],
      });
    },
  );
  test(
    'epic and resource updates match server DTOs without overwriting task fields',
    () async {
      final adapter = _ExtrasAdapter();
      final repo = TaskDetailsRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      await repo.updateEpics('t', ['e']);
      expect(adapter.lastData, {
        'epicIds': ['e'],
      });
      await repo.saveResource(
        't',
        const TaskResourceModel(
          id: 'r',
          name: 'Бюджет',
          planValue: 100,
          factValue: 10,
          order: 3,
        ),
        create: true,
      );
      expect(adapter.lastPath, 'tasks/t/resources');
      expect(adapter.lastData, {
        'name': 'Бюджет',
        'planValue': '100.0000',
        'factValue': '10.0000',
      });
      await repo.saveResource(
        't',
        const TaskResourceModel(id: 'r', name: 'Бюджет'),
        create: false,
      );
      expect(adapter.lastPath, 'resources/r');
      await repo.deleteResource('r');
      expect(adapter.lastPath, 'resources/r');
    },
  );
}

Future<TaskDetailsCubit> _mountExtras(
  WidgetTester tester,
  _ExtrasAdapter adapter,
  TaskExtraTab tab, {
  double textScale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final cubit = TaskDetailsCubit(
    TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
    _Profile(),
  );
  addTearDown(cubit.close);
  await tester.runAsync(() => cubit.load('t'));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTaskExtras(context, tab),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
  return cubit;
}

class _Profile implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async =>
      const UserProfile(id: 'me', name: 'Имя', email: 'me@example.test');
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) => getCurrentUser();
}

class _ExtrasAdapter implements HttpClientAdapter {
  bool failFactWithConcurrentResource = false;
  final resources = <Map<String, Object?>>[];
  int nextResourceId = 0;
  bool fail = false, offline = false;
  bool failCatalog = false, failEpics = false;
  int patches = 0;
  Completer<void>? patchGate;
  Map<String, Object?> catalog = {'shared': [], 'personal': []};
  List<Map<String, Object?>> epics = [];
  List<String> epicIds = [];
  String? epicProjectId;
  String? lastPath;
  dynamic lastData;
  Map<String, dynamic> detail = {
    'description': 'Описание',
    'unknown': {'retained': true},
    'personalLabels': {
      'other': [
        {'id': 'private', 'text': 'Чужая метка'},
      ],
    },
    'cover': {'type': 'image', 'fileId': 'cover'},
    'files': [
      {'id': 'cover', 'name': 'cover.png'},
    ],
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    lastPath = options.path;
    lastData = options.data;
    if (options.method == 'PATCH' && options.path == 'project-tasks/t') {
      patches++;
      if (patchGate != null) await patchGate!.future;
    }
    if (offline && options.method != 'GET') {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (fail && options.method != 'GET') return _json({}, 403);
    if (options.path.endsWith('/label-catalog')) {
      return failCatalog ? _json({}, 503) : _json(catalog);
    }
    if (options.path == 'epics') {
      epicProjectId = options.queryParameters['projectId'] as String?;
      return failEpics ? _json({}, 503) : _json(epics);
    }
    if (options.method == 'PATCH' &&
        options.data is Map &&
        (options.data as Map).containsKey('epicIds')) {
      epicIds = List<String>.from((options.data as Map)['epicIds'] as List);
    }
    if (options.path.startsWith('resources/') &&
        options.path.endsWith('/history')) {
      return _json({'items': [], 'nextCursor': null});
    }
    if (options.path == 'tasks/t/resources' && options.method == 'POST') {
      final data = Map<String, Object?>.from(options.data as Map);
      if (failFactWithConcurrentResource && data['name'] == 'Факт') {
        resources.add({'id': 'other-user', 'name': 'Чужой', 'order': 3});
        return _json({}, 503);
      }
      resources.add({
        ...data,
        'id': 'resource-${nextResourceId++}',
        'order': resources.length,
      });
      return _json(resources.last);
    }
    if (options.path.startsWith('resources/')) {
      final id = options.path.split('/').last;
      if (options.method == 'DELETE') {
        resources.removeWhere((r) => r['id'] == id);
      }
      if (options.method == 'PATCH') {
        for (final r in resources.where((r) => r['id'] == id)) {
          r.addAll(Map<String, Object?>.from(options.data as Map));
        }
      }
    }
    if (options.path.endsWith('/history') ||
        options.path == 'kanban-columns' ||
        options.path == 'epics') {
      return _json([]);
    }
    if (options.method == 'PATCH' &&
        options.data is Map &&
        (options.data as Map).containsKey('detail')) {
      detail = Map<String, dynamic>.from(
        (options.data as Map)['detail'] as Map,
      );
    }
    return _json({
      'id': 't',
      'title': 'Задача',
      'projectId': 'p',
      'detail': detail,
      'resources': resources,
      'epics': epics
          .where((e) => epicIds.contains(e['id']))
          .map((e) => {'epicId': e['id'], 'epic': e})
          .toList(),
    });
  }

  ResponseBody _json(Object value, [int code = 200]) => ResponseBody.fromString(
    jsonEncode(value),
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _Picker extends FilePickerPlatform {
  List<PlatformFile> files = [_MemoryFile()];
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => files;
}

final class _MemoryFile extends PlatformFile {
  _MemoryFile({this.oversized = false});
  final bool oversized;
  @override
  String get name => 'report.txt';
  @override
  Future<int?> length() async => null;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield oversized
        ? Uint8List(TaskFilePicker.maxFileBytes + 1)
        : Uint8List.fromList([72, 105]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
