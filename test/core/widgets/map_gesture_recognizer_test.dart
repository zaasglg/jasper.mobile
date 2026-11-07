import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/widgets/map_gesture_recognizer.dart';

class _TrackingMapRecognizer extends MapGestureRecognizer {
  bool accepted = false;
  @override
  void acceptGesture(int pointer) {
    accepted = true;
    super.acceptGesture(pointer);
  }
}

void main() {
  testWidgets('single-finger swipe over map scrolls dashboard', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final recognizer = _TrackingMapRecognizer();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              RawGestureDetector(
                gestures: {
                  _TrackingMapRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _TrackingMapRecognizer
                      >(() => recognizer, (_) {}),
                },
                child: const SizedBox(
                  key: Key('map'),
                  height: 220,
                  width: double.infinity,
                  child: ColoredBox(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 1400),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.byKey(const Key('map')), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(recognizer.accepted, isFalse);
  });

  testWidgets('two-finger touch belongs to map', (tester) async {
    final recognizer = _TrackingMapRecognizer();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RawGestureDetector(
            gestures: {
              _TrackingMapRecognizer:
                  GestureRecognizerFactoryWithHandlers<_TrackingMapRecognizer>(
                    () => recognizer,
                    (_) {},
                  ),
            },
            child: const SizedBox.expand(child: ColoredBox(color: Colors.grey)),
          ),
        ),
      ),
    );
    final first = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final second = await tester.startGesture(
      const Offset(150, 100),
      pointer: 2,
    );
    await tester.pump();
    expect(recognizer.accepted, isTrue);
    await second.up();
    await first.up();
  });
}
