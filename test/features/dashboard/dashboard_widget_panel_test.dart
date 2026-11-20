import 'package:jospar/features/dashboard/domain/entities/dashboard_widget_options.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/domain/entities/dashboard_widget_slot.dart';
import 'package:jospar/features/dashboard/presentation/cubit/dashboard_layout_cubit.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_widget_panel.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_collapsible_widget.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_expandable_content.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_widget_skeleton.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'dashboard_layout_test.dart' show FakeDashboardRepository;

void main() {
  const project = ProjectModel(
    id: 'p',
    code: 'P',
    name: 'Школа',
    workspaceId: 'w',
    start: null,
    end: null,
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('scrolling back preserves loaded cards on ${platform.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cubit = DashboardLayoutCubit(_Data());
      addTearDown(cubit.close);
      await cubit.configure('u', 'w');
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: ListView.builder(
                controller: scroll,
                itemCount: 12,
                itemBuilder: (context, index) => index == 0
                    ? const DashboardCollapsibleWidget(
                        title: 'Общие данные',
                        icon: Icons.dashboard,
                        child: DashboardExpandableContent(
                          child: DashboardWidgetPanel(
                            slot: DashboardWidgetSlot(
                              id: 'kpi-group',
                              instanceId: 'kpi',
                            ),
                            expandContent: true,
                            projects: [project],
                            workspaceId: 'w',
                            userId: 'u',
                          ),
                        ),
                      )
                    : SizedBox(height: 400, child: Text('Card $index')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byType(DashboardWidgetPanel);
      final initialState = tester.state(panel);
      final initialHeight = tester.getSize(panel).height;
      for (var pass = 0; pass < 3; pass++) {
        scroll.jumpTo(2800);
        await tester.pumpAndSettle();
        expect(find.text('Card 7').hitTestable(), findsOneWidget);
        scroll.jumpTo(0);
        // Inspect the first returning frame, before cached futures can settle.
        await tester.pump();
        expect(tester.state(panel), same(initialState));
        expect(find.byType(DashboardWidgetSkeleton), findsNothing);
        expect(tester.getSize(panel).height, initialHeight);
        expect(scroll.offset, 0);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('dashboard_widget_collapse')));
      await tester.pumpAndSettle();
      final collapsedHeight = tester
          .getSize(find.byType(DashboardCollapsibleWidget))
          .height;
      scroll.jumpTo(2800);
      await tester.pumpAndSettle();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard_widget_expand')), findsOneWidget);
      expect(
        tester.getSize(find.byType(DashboardCollapsibleWidget)).height,
        collapsedHeight,
      );
      await tester.tap(find.byKey(const Key('dashboard_widget_expand')));
      await tester.pumpAndSettle();
      expect(tester.state(panel), same(initialState));
      expect(tester.getSize(panel).height, initialHeight);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(initialState.mounted, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> panel(
    WidgetTester tester,
    DashboardWidgetSlot slot, {
    bool expandContent = false,
    bool completedRecommendations = false,
  }) async {
    final cubit = DashboardLayoutCubit(
      _Data()
        ..recommendations = slot.id == 'daily-motivation'
        ..completedRecommendations = completedRecommendations,
    );
    addTearDown(cubit.close);
    await cubit.configure('u', 'w');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DashboardWidgetPanel(
                    expandContent: expandContent,
                    slot: slot,
                    projects: const [project],
                    workspaceId: 'w',
                    userId: 'u',
                  ),
                  if (expandContent) const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('swiping inside expanded recommendations scrolls dashboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await panel(
      tester,
      const DashboardWidgetSlot(id: 'daily-motivation', instanceId: 'ai'),
      expandContent: true,
    );
    final before = tester.getTopLeft(find.byType(DashboardWidgetPanel)).dy;
    await tester.drag(
      find.textContaining('отстаёт по срокам'),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(DashboardWidgetPanel)).dy,
      lessThan(before),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'returning from a task refreshes dashboard data without recreating the panel',
    (tester) async {
      final repository = _Data();
      final cubit = DashboardLayoutCubit(repository);
      await cubit.configure('u', 'w');
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: Scaffold(
                body: BlocBuilder<DashboardLayoutCubit, DashboardLayoutState>(
                  builder: (context, state) => DashboardWidgetPanel(
                    revision: state.revision,
                    slot: const DashboardWidgetSlot(
                      id: 'tasks-summary',
                      instanceId: 's',
                      options: DashboardWidgetOptions(mode: 'epic'),
                    ),
                    projects: const [project],
                    workspaceId: 'w',
                    userId: 'u',
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Назад к дашборду'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(repository.taskLoads, 1);
      await tester.tap(find.text('Строительство'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Согласовать план'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назад к дашборду'));
      await tester.pumpAndSettle();
      expect(repository.taskLoads, 2);
      expect(find.byType(DashboardWidgetPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('KPI counts completed and overdue workspace tasks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await panel(
      tester,
      const DashboardWidgetSlot(id: 'kpi-group', instanceId: 'kpi'),
    );
    expect(find.text('всего задач'), findsOneWidget);
    expect(find.text('Общие данные'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Просрочено'), findsOneWidget);
    await tester.ensureVisible(find.text('Просрочено'));
    await tester.tap(find.text('Просрочено'));
    await tester.pumpAndSettle();
    expect(find.text('Задачи · Просрочено'), findsOneWidget);
    expect(find.text('1 проект · 1 задача'), findsOneWidget);
    expect(find.text('Согласовать план'), findsOneWidget);
    expect(find.text('Подготовить схему'), findsNothing);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Фильтр проектов'));
    await tester.tap(find.byTooltip('Фильтр проектов'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-option-p')));
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.text('Все проекты'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('scrum respects saved epic mode and project filter', (
    tester,
  ) async {
    await panel(
      tester,
      const DashboardWidgetSlot(
        id: 'tasks-summary',
        instanceId: 's',
        options: DashboardWidgetOptions(mode: 'epic', projectIds: ['p']),
      ),
    );
    expect(find.text('Строительство'), findsOneWidget);
    expect(find.text('Без эпика'), findsNothing);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 из 2 выполнено'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('resources pair plan and fact rows using website metric ids', (
    tester,
  ) async {
    await panel(
      tester,
      const DashboardWidgetSlot(
        id: 'resource',
        instanceId: 'r',
        options: DashboardWidgetOptions(
          resourceProjectId: 'p',
          resourceModeByProject: {'p': 'selected'},
          resourceNamesByProject: {
            'p': ['["Бюджет","Расход"]'],
          },
        ),
      ),
    );
    expect(find.text('Бюджет / Расход'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.value, .5);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'AI renders teammate overdue recommendations instead of a quote',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await panel(
        tester,
        const DashboardWidgetSlot(id: 'daily-motivation', instanceId: 'ai'),
      );
      expect(find.text('AI РЕКОМЕНДАЦИИ'), findsOneWidget);
      expect(
        find.textContaining('отстаёт по срокам', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Алия', findRichText: true), findsOneWidget);
      expect(find.text('«Начните с главного»'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'completed progress tasks never create overdue AI recommendations',
    (tester) async {
      await panel(
        tester,
        const DashboardWidgetSlot(
          id: 'daily-motivation',
          instanceId: 'done-ai',
        ),
        completedRecommendations: true,
      );
      expect(find.text('Нет рекомендаций'), findsOneWidget);
      expect(find.textContaining('отстаёт по срокам'), findsNothing);
    },
  );
  testWidgets(
    'mentions obey saved project filter and tolerate malformed dates',
    (tester) async {
      await panel(
        tester,
        const DashboardWidgetSlot(
          id: 'mentions',
          instanceId: 'm',
          options: DashboardWidgetOptions(projectIds: ['p']),
        ),
      );
      expect(find.text('Проверить смету'), findsOneWidget);
      expect(find.text('Другой проект'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('team uses membership and shows task load', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await panel(tester, const DashboardWidgetSlot(id: 'team', instanceId: 't'));
    expect(find.text('Алия'), findsOneWidget);
    expect(find.text('2 задачи'), findsOneWidget);
    expect(find.text('1 проект'), findsOneWidget);
    await tester.tap(find.text('Все проекты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Школа'));
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.text('Проекты: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Список'));
    await tester.pumpAndSettle();
    expect(find.text('Участник'), findsOneWidget);
    expect(find.text('Проср.'), findsOneWidget);
    await tester.tap(find.byTooltip('Эффективность'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 из 2 завершено'), findsOneWidget);
    await tester.tap(find.text('Алия'));
    await tester.pumpAndSettle();
    expect(find.text('Задачи · Алия'), findsOneWidget);
    expect(find.text('Согласовать план'), findsOneWidget);
    expect(find.text('Подготовить схему'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Data extends FakeDashboardRepository {
  bool recommendations = false;
  bool completedRecommendations = false;
  int taskLoads = 0;
  @override
  Future<List<Map<String, dynamic>>> tasks(
    String workspaceId,
    List<String> projectIds,
  ) async {
    taskLoads++;
    return [
      if (recommendations)
        for (var i = 0; i < 2; i++)
          {
            'id': 'overdue-$i',
            'progress': completedRecommendations ? 100 : 0,
            'projectId': 'p',
            'status': 'TODO',
            'end': '2020-01-01',
            'assignees': [
              {'userId': 'v'},
            ],
          },
      {
        'id': 'one',
        'projectId': 'p',
        'title': 'Согласовать план',
        'end': '2020-01-01',
        'status': 'PROGRESS',
        'progress': 50,
        'assignees': [
          {'userId': 'u'},
        ],
        'epics': [
          {
            'epicId': 'e',
            'epic': {'name': 'Строительство'},
          },
        ],
        'resources': [
          {'name': 'Бюджет', 'planValue': '100', 'factValue': '0', 'order': 0},
          {'name': 'Расход', 'planValue': '0', 'factValue': '50', 'order': 1},
        ],
      },
      {
        'id': 'two',
        'projectId': 'p',
        'title': 'Подготовить схему',
        'status': 'DONE',
        'progress': 100,
        'assignees': [
          {'userId': 'u'},
        ],
      },
    ];
  }

  @override
  Future<dynamic> widgetData(String workspaceId, String kind) async =>
      switch (kind) {
        'scrum-metadata' => {
          'columns': [
            {
              'projectId': 'p',
              'name': 'В работе',
              'statusMap': 'PROGRESS',
              'color': '#6D5FE0',
            },
            {
              'projectId': 'p',
              'name': 'Готово',
              'statusMap': 'DONE',
              'color': '#10B981',
            },
          ],
          'epics': [
            {
              'id': 'e',
              'projectId': 'p',
              'name': 'Строительство',
              'color': '#6D5FE0',
            },
          ],
        },
        'recommendation-users' => {
          'currentUser': {'id': 'u', 'role': 'ADMIN'},
          'users': [
            {'id': 'u', 'name': 'Я'},
            {'id': 'v', 'name': 'Алия'},
          ],
        },
        'daily-motivation' => {
          'quote': {'text': 'Начните с главного', 'author': 'Рабочий фокус'},
          'focusTask': {'id': 'one', 'title': 'Согласовать план'},
          'stats': {'inProgressCount': 1, 'overdueCount': 1},
        },
        'team' => [
          {
            'userId': 'u',
            'user': {'id': 'u', 'name': 'Алия'},
          },
        ],
        'mentions' => [
          {
            'id': 'one',
            'projectId': 'p',
            'text': '<p>Проверить смету</p>',
            'createdAt': 'bad',
          },
          {'id': 'two', 'projectId': 'other', 'text': 'Другой проект'},
        ],
        _ => [],
      };
}
