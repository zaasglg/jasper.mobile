import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_fx/src/liquid_glass.dart';

void main() {
  testWidgets('shader layout retains its blur child across relayouts', (
    tester,
  ) async {
    final sizes = <Size>[];
    Widget app(double width) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 90,
          child: LiquidGlassShaderBackdrop(
            filterForSize: (size) {
              sizes.add(size);
              return ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
            },
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: const SizedBox.expand(key: Key('glass-child')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(390));
    expect(
      tester.getSize(find.byKey(const Key('glass-child'))),
      const Size(390, 90),
    );
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(280));
    expect(
      tester.getSize(find.byKey(const Key('glass-child'))),
      const Size(280, 90),
    );
    expect(sizes, containsAll([const Size(390, 90), const Size(280, 90)]));
    expect(tester.takeException(), isNull);
  });
}
