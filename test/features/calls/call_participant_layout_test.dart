import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/presentation/call_screen.dart';

void main() {
  testWidgets('remote fills screen and local remains an inset preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: CallPictureInPicture(
            remote: ColoredBox(key: Key('remote'), color: Colors.blue),
            local: ColoredBox(key: Key('local'), color: Colors.green),
          ),
        ),
      ),
    );
    final screen = tester.getRect(find.byType(CallPictureInPicture));
    final remote = tester.getRect(find.byKey(const Key('remote')));
    final local = tester.getRect(find.byKey(const Key('local')));
    expect(remote, screen);
    expect(screen.contains(local.topLeft), isTrue);
    expect(screen.contains(local.bottomRight), isTrue);
    expect(local.width, lessThan(screen.width / 2));
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('self preview drags, stays in bounds and survives rebuilds', (
    tester,
  ) async {
    Widget screen() => MaterialApp(
      home: SizedBox.expand(
        child: CallPictureInPicture(
          remote: const ColoredBox(color: Colors.blue),
          local: const ColoredBox(key: Key('local'), color: Colors.green),
        ),
      ),
    );
    await tester.pumpWidget(screen());
    final preview = find.byKey(const Key('call_self_preview'));
    final before = tester.getTopLeft(preview);
    await tester.drag(preview, const Offset(-150, 80));
    await tester.pump();
    final moved = tester.getTopLeft(preview);
    expect(moved.dx, lessThan(before.dx));
    expect(moved.dy, greaterThan(before.dy));
    await tester.pumpWidget(screen());
    expect(tester.getTopLeft(preview), moved);
    for (final delta in [
      const Offset(-2000, -2000),
      const Offset(2000, 2000),
    ]) {
      await tester.drag(preview, delta);
      await tester.pump();
      final bounds = tester.getRect(find.byType(CallPictureInPicture));
      final rect = tester.getRect(preview);
      expect(bounds.contains(rect.topLeft), isTrue);
      expect(bounds.contains(rect.bottomRight), isTrue);
    }
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(360, 360), const Size(738, 300)]) {
    testWidgets('two videos fit without scrolling at $size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.fromSize(
              size: size,
              child: const CallParticipantLayout(
                children: [
                  ColoredBox(key: Key('local'), color: Colors.blue),
                  ColoredBox(key: Key('remote'), color: Colors.green),
                ],
              ),
            ),
          ),
        ),
      );
      final bounds = tester.getRect(find.byType(CallParticipantLayout));
      final local = tester.getRect(find.byKey(const Key('local')));
      final remote = tester.getRect(find.byKey(const Key('remote')));
      expect(bounds.contains(local.topLeft), isTrue);
      expect(bounds.contains(remote.bottomRight), isTrue);
      expect(local.overlaps(remote), isFalse);
      expect(local.size, remote.size);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
