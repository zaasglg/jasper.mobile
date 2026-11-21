import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/dashboard/presentation/utils/dashboard_options_changes.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_widget_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_resource_widget.dart';
import 'package:jospar/features/dashboard/presentation/cubit/dashboard_layout_cubit.dart';
import 'dashboard_layout_test.dart' show FakeDashboardRepository, fixture;

void main() {
  testWidgets(
    'resource rings aggregate pairs, switch to task rings and filter labels',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final patches = <Map<String, dynamic>>[];
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardResourceWidget(
                projects: const [
                  ProjectModel(
                    id: 'p',
                    code: 'P',
                    name: 'Школа',
                    workspaceId: 'w',
                    start: null,
                    end: null,
                  ),
                ],
                options: const DashboardWidgetOptions(),
                onChanged: (patch) async {
                  patches.add(patch);
                  return true;
                },
                onOpenTask: (id) async {
                  opened = id;
                },
                tasks: const [
                  {
                    'id': 'one',
                    'projectId': 'p',
                    'displayId': 'PR-1',
                    'title': 'Первая',
                    'resources': [
                      {
                        'name': 'Бюджет',
                        'planValue': 100,
                        'factValue': 999,
                        'order': 0,
                      },
                      {
                        'name': 'Затраты',
                        'planValue': 999,
                        'factValue': 50,
                        'order': 1,
                      },
                      {'name': 'Непарный', 'planValue': 5, 'order': 2},
                    ],
                    'detail': {
                      'labels': [
                        {'text': 'Стройка', 'color': '#abc'},
                      ],
                    },
                  },
                  {
                    'id': 'two',
                    'projectId': 'p',
                    'displayId': 'PR-2',
                    'title': 'Вторая',
                    'resources': [
                      {
                        'name': 'Затраты',
                        'planValue': 999,
                        'factValue': 150,
                        'order': 1,
                      },
                      {
                        'name': 'Бюджет',
                        'planValue': 300,
                        'factValue': 999,
                        'order': 0,
                      },
                    ],
                    'detail': {
                      'labels': [
                        {'text': 'Другое', 'color': '#abc'},
                      ],
                    },
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Бюджет / Затраты'), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      await tester.tap(find.text('Метрики'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Все метрики'));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect((patches.last['resourceModeByProject'] as Map)['all'], 'tasks');
      expect(find.text('PR-1 · Первая'), findsNWidgets(2));
      expect(find.text('PR-2 · Вторая'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      await tester.tap(find.text('PR-2 · Вторая'));
      expect(opened, 'two');
      await tester.tap(find.byTooltip('Отбор ресурсов'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-option-labels')));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Все метки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Стройка'));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(find.text('PR-2 · Вторая'), findsNothing);
      expect(find.text('PR-1 · Первая'), findsNWidgets(2));
      expect(patches.last['resourceLabelKeys'], ['["стройка","#abc"]']);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'resource settings merge into latest config without changing desktop coordinates or other projects',
    () async {
      final repository = FakeDashboardRepository()..value = fixture();
      final cubit = DashboardLayoutCubit(repository);
      addTearDown(cubit.close);
      await cubit.configure('u', 'w');
      final original = repository.value;
      repository.value = original.copyWith(
        widgets: original.widgets
            .map(
              (slot) => slot.instanceId == 'resource-custom'
                  ? slot.copyWith(
                      options: patchDashboardOptions(slot.options, {
                        'resourceModeByProject': {
                          'p': 'selected',
                          'q': 'tasks',
                        },
                        'remote': 'keep',
                      }),
                    )
                  : slot,
            )
            .toList(),
      );
      final latest = repository.value;
      expect(
        await cubit.saveWidgetOptions('resource-custom', {
          'resourceModeByProject': {'p': 'all'},
          'resourceProjectId': 'p',
        }),
        isTrue,
      );
      final saved = repository.saved.single.$2;
      expect(saved.layouts, latest.layouts);
      final resource = saved.widgets.firstWhere(
        (s) => s.instanceId == 'resource-custom',
      );
      expect(resource.options.resourceModeByProject, {
        'p': 'all',
        'q': 'tasks',
      });
      expect(resource.options.unknownOptions['remote'], 'keep');
      expect(
        saved.widgets.firstWhere((s) => s.instanceId == 'future'),
        latest.widgets.firstWhere((s) => s.instanceId == 'future'),
      );
    },
  );
  test(
    'resource settings remain a draft in edit mode and can be cancelled',
    () async {
      final repository = FakeDashboardRepository()..value = fixture();
      final cubit = DashboardLayoutCubit(repository);
      addTearDown(cubit.close);
      await cubit.configure('u', 'w');
      final original = cubit.state.layout;
      cubit.enterEdit();
      expect(
        await cubit.saveWidgetOptions('resource-custom', {
          'resourceFilterType': 'epics',
        }),
        isTrue,
      );
      expect(repository.saved, isEmpty);
      cubit.cancelEdit();
      expect(cubit.state.current, original);
    },
  );
  testWidgets(
    'metric rings reorder by long press and persist the selected metric order',
    (tester) async {
      final patches = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardResourceWidget(
              projects: const [
                ProjectModel(
                  id: 'p',
                  code: 'P',
                  name: 'Школа',
                  workspaceId: 'w',
                  start: null,
                  end: null,
                ),
              ],
              options: const DashboardWidgetOptions(),
              onChanged: (patch) async {
                patches.add(patch);
                return true;
              },
              onOpenTask: (_) async {},
              tasks: const [
                {
                  'id': 'one',
                  'projectId': 'p',
                  'resources': [
                    {'name': 'План А', 'planValue': 100, 'order': 0},
                    {'name': 'Факт А', 'factValue': 50, 'order': 1},
                    {'name': 'План Б', 'planValue': 200, 'order': 2},
                    {'name': 'Факт Б', 'factValue': 50, 'order': 3},
                  ],
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('План А / Факт А')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(find.text('План Б / Факт Б')));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(patches.single['resourceModeByProject'], {'all': 'selected'});
      expect(patches.single['resourceNamesByProject'], {
        'all': ['["План Б","Факт Б"]', '["План А","Факт А"]'],
      });
      expect(tester.takeException(), isNull);
    },
  );
}
