import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/collaboration/data/collaboration_models.dart';
import 'package:jospar/features/collaboration/presentation/workspace_participants_panel.dart';

void main() {
  testWidgets('workspace directory searches email and switches guest filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorkspaceParticipantsPanel(
              actions: (_) => null,
              members: const [
                SpaceMember(
                  userId: '',
                  name: 'Алия',
                  email: 'aliya@example.test',
                ),
                SpaceMember(
                  userId: '',
                  name: 'Гость',
                  access: 'GUEST',
                  details: {'projectCount': 2},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Алия'), findsOneWidget);
    expect(find.text('Гость'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ALIYA@');
    await tester.pump();
    expect(find.text('Алия'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.ensureVisible(find.text('Гости нескольких досок · 1'));
    await tester.tap(find.text('Гости нескольких досок · 1'));
    await tester.pump();
    expect(find.text('Гость'), findsOneWidget);
    expect(find.text('Алия'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
