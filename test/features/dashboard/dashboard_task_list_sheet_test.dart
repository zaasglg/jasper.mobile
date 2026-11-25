import 'package:jospar/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:flutter/material.dart';
import 'package:jospar/core/widgets/task_completion_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/dashboard_task_list_sheet.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('allocation filters work on a narrow phone, dark: $dark', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: const Scaffold(
            body: DashboardTaskListSheet(
              title: 'Не распределено',
              allocationFilters: true,
              projects: [
                ProjectModel(
                  id: 'p',
                  code: 'P',
                  name: 'Школа',
                  workspaceId: 'w',
                  start: null,
                  end: null,
                ),
              ],
              tasks: [
                {
                  'id': 'one',
                  'projectId': 'p',
                  'displayId': 'PR-1',
                  'title': 'Без даты',
                  'status': 'DONE',
                  'progress': 0,
                  'assignees': [
                    {'userId': 'u'},
                  ],
                },
                {
                  'id': 'two',
                  'projectId': 'p',
                  'displayId': 'PR-2',
                  'title': 'Без исполнителя',
                  'status': 'PROGRESS',
                  'end': '2099-11-14',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Задачи · Не распределено'), findsOneWidget);
      expect(find.text('PR-1'), findsOneWidget);
      expect(find.text('PR-2'), findsOneWidget);
      expect(find.text('Готово'), findsOneWidget);
      // Column placement alone does not imply completion on the web.
      expect(
        tester
            .widgetList<TaskCompletionIndicator>(
              find.byType(TaskCompletionIndicator),
            )
            .map((indicator) => indicator.completed),
        [false, false],
      );
      expect(find.text('В работе'), findsOneWidget);
      final colors = AppPalette(dark);
      final filter = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Все'),
      );
      expect(filter.style!.backgroundColor!.resolve({}), colors.badgeSurface);
      final status = tester.widget<Container>(
        find
            .ancestor(of: find.text('Готово'), matching: find.byType(Container))
            .first,
      );
      expect((status.decoration! as BoxDecoration).color, colors.subtleSurface);
      final card = tester.widget<Material>(
        find
            .ancestor(of: find.text('PR-1'), matching: find.byType(Material))
            .first,
      );
      expect((card.shape! as RoundedRectangleBorder).side.color, colors.border);

      final filterBar = find.byType(SingleChildScrollView).last;
      await tester.tap(find.text('Без срока').first);
      await tester.pumpAndSettle();
      expect(find.text('PR-1'), findsOneWidget);
      expect(find.text('PR-2'), findsNothing);
      await tester.drag(filterBar, const Offset(-240, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Без участника').first);
      await tester.pumpAndSettle();
      expect(find.text('PR-1'), findsNothing);
      expect(find.text('PR-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
