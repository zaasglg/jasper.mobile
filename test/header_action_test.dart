import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:jospar/core/widgets/header_action.dart';

void main() {
  testWidgets('header actions fit narrow toolbar and remain tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FTheme(
          data: FTheme.neutral.light.touch,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Очень длинное название рабочего пространства',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                for (var i = 0; i < 4; i++)
                  HeaderAction(
                    tooltip: 'action-$i',
                    onPressed: () => taps++,
                    icon: const SizedBox.square(
                      dimension: 32,
                      child: Icon(Icons.person),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(ValueKey('header-action-$i')));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
    expect(taps, 4);
  });
}
