import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_activity_widget.dart';

void main() {
  testWidgets('login activity is compact and fits enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: DashboardActivityWidget(
                entries: const [
                  {
                    'id': 'login',
                    'type': 'USER_LOGIN',
                    'user': {'id': 'u', 'name': 'СуперАдмин Тест'},
                    'description':
                        'СуперАдмин Тест вошёл(ла) в систему в 00:56',
                    'createdAt': '2026-11-21T00:56:00Z',
                  },
                ],
                onOpenTask: (_) async {},
                loadCategory: (_) async => [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('СуперАдмин Тест', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Вход в систему'), findsOneWidget);
    expect(find.textContaining('вошёл', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'activity renders event details, opens tasks and switches server categories',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardActivityWidget(
                entries: const [
                  {
                    'id': 'one',
                    'type': 'TASK_UPDATED',
                    'description': 'обновил задачу',
                    'user': {'id': 'u', 'name': 'Алия'},
                    'metadata': {'taskId': 't', 'displayId': 'PR-1'},
                    'createdAt': '2026-10-31T12:25:00Z',
                  },
                ],
                onOpenTask: (id) async {
                  opened = id;
                },
                loadCategory: (category) async => category == 'tasks'
                    ? [
                        {
                          'type': 'TASK_UPDATED',
                          'description': 'Старый результат',
                        },
                      ]
                    : [
                        {
                          'type': 'PROJECT_CREATED',
                          'description': 'Новый проект',
                        },
                      ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Последняя активность'), findsOneWidget);
      expect(find.text('Задача обновлена'), findsOneWidget);
      expect(find.textContaining('PR-1', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Задача обновлена'));
      expect(opened, 't');
      await tester.tap(find.byTooltip('Категория активности'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-option-tasks')));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Категория активности'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-option-projects')));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('Проект создан'), findsOneWidget);
      expect(
        find.textContaining('Новый проект', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Старый результат', findRichText: true),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
