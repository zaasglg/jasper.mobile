import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/data/call_models.dart';
import 'package:jospar/features/calls/presentation/incoming_call_screen.dart';

void main() {
  const room = CallRoom(
    id: 'r',
    workspaceId: 'w',
    callerName: 'Абылайхан Тастанбек',
  );
  testWidgets('incoming screen works above Navigator without an Overlay', (
    tester,
  ) async {
    var accepted = 0;
    var declined = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: const SizedBox.shrink(),
        builder: (context, child) => IncomingCallScreen(
          room: room,
          onAccept: () => accepted++,
          onDecline: () => declined++,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Overlay), findsNothing);
    expect(find.byTooltip('Принять'), findsNothing);
    await tester.tap(find.byKey(const Key('incoming_accept')));
    await tester.tap(find.byKey(const Key('incoming_decline')));
    expect(accepted, 1);
    expect(declined, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('incoming actions work and fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var accepted = 0;
    var declined = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: IncomingCallScreen(
          room: room,
          onAccept: () => accepted++,
          onDecline: () => declined++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('incoming_accept')));
    await tester.tap(find.byKey(const Key('incoming_decline')));
    expect(accepted, 1);
    expect(declined, 1);
    expect(find.text(room.callerName), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: IncomingCallScreen(
          room: room,
          busy: true,
          onAccept: () => accepted++,
          onDecline: () => declined++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('incoming_accept')));
    await tester.tap(find.byKey(const Key('incoming_decline')));
    expect(accepted, 1);
    expect(declined, 1);
  });
}
