import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/kanban/data/models/card_view_settings.dart';
import 'package:jospar/features/kanban/presentation/widgets/task_card.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/task_label_model.dart';

void main() {
  test(
    'settings round trip, tolerate unknown fields and keep new fields visible',
    () {
      final settings = const CardViewSettings()
          .toggle(CardField.id)
          .toggle(CardField.checklists);
      expect(CardViewSettings.fromJson(settings.toJson()), settings);
      expect(settings.shows(CardField.files), isTrue);
      expect(settings.toggle(CardField.id).shows(CardField.id), isTrue);
      expect(
        CardViewSettings.fromJson({
          'hidden': ['unknown'],
        }).hidden,
        isEmpty,
      );
    },
  );

  test('parses cover and resource counts and preserves them in copies', () {
    final task = ProjectTaskModel.fromJson({
      'detail': {
        'cover': {'type': 'color', 'color': '#123456'},
      },
      'resources': [
        {'id': 'r'},
      ],
    });
    expect(task.cover['color'], '#123456');
    expect(task.resourceCount, 1);
    expect(ProjectTaskModel.fromJson(task.toJson()), task);
    expect(task.copyWith(title: 'Новое имя').resourceCount, 1);
  });

  testWidgets('card elements hide independently, including personal labels', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    const task = ProjectTaskModel(
      id: 'internal',
      displayId: 'P-1',
      projectId: 'p',
      status: 'TODO',
      title: 'Название',
      checklistTotal: 2,
      checklistCompleted: 1,
      fileCount: 3,
      commentCount: 4,
      resourceCount: 2,
      estimate: 60,
      detail: '{"cover":{"type":"color","color":"#123456"}}',
      epics: [TaskEpicModel(id: 'e', name: 'Эпик')],
      labels: [
        TaskLabelModel(id: 'l', text: 'Общая'),
        TaskLabelModel(id: 'p', text: 'Личная', isPersonal: true),
      ],
    );
    Widget card(CardViewSettings settings) => MaterialApp(
      home: Scaffold(
        body: TaskCard(task: task, cardView: settings),
      ),
    );
    await tester.pumpWidget(card(const CardViewSettings()));
    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('Общая'), findsOneWidget);
    expect(find.text('Личная'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('60 мин'), findsOneWidget);
    await tester.pumpWidget(
      card(const CardViewSettings(hidden: {CardField.labels})),
    );
    expect(find.text('Общая'), findsNothing);
    expect(find.text('Личная'), findsOneWidget);
    await tester.pumpWidget(
      card(CardViewSettings(hidden: CardField.values.toSet())),
    );
    for (final text in ['P-1', 'Эпик', 'Личная', '1/2', '60 мин']) {
      expect(find.text(text), findsNothing);
    }
    expect(find.text('Название'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
