import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_checklists_editor.dart';

void main() {
  testWidgets('dark checklist and inline creation retain dark surfaces', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: TaskChecklistsEditor(
              enabled: true,
              checklists: [
                TaskChecklistModel(
                  id: 'list',
                  name: 'Проверка',
                  items: [
                    TaskChecklistItemModel(id: 'a', text: 'Готово', done: true),
                    TaskChecklistItemModel(id: 'b', text: 'В работе'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    const colors = AppPalette(true);
    final card = tester.widget<Container>(
      find
          .ancestor(of: find.text('Проверка'), matching: find.byType(Container))
          .first,
    );
    expect((card.decoration! as BoxDecoration).color, colors.subtleSurface);
    expect(tester.widget<Text>(find.text('В работе')).style!.color, colors.ink);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .color,
      colors.accent,
    );
    await tester.tap(find.text('Добавить пункт'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.fillColor,
      colors.badgeSurface,
    );
    expect(tester.takeException(), isNull);
  });
}
