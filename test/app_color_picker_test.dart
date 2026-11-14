import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/widgets/app_color_picker.dart';

void main() {
  testWidgets('presets and custom HEX update the controlled color', (
    tester,
  ) async {
    var value = '#6D5FE0';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppColorPicker(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('#E11D48'));
    await tester.pump();
    expect(value, '#E11D48');
    await tester.tap(find.byTooltip('Другой цвет'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('color_hex_input')), '#123abc');
    await tester.pump();
    expect(value, '#123ABC');
    await tester.enterText(find.byKey(const Key('color_hex_input')), '#12');
    expect(value, '#123ABC');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'web palette token displays matching color and canonical HEX without changing value',
    (tester) async {
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppColorPicker(
              value: 'var(--label-red)',
              onChanged: (_) => changed = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Другой цвет'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('color_hex_input')))
            .controller!
            .text,
        '#E11D48',
      );
      expect(changed, isFalse);
    },
  );

  testWidgets('disabled palette does not change the color', (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppColorPicker(
            value: '#6D5FE0',
            enabled: false,
            onChanged: (_) => changed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('#E11D48'));
    await tester.tap(find.byTooltip('Другой цвет'));
    await tester.pump();
    expect(changed, isFalse);
    expect(find.byKey(const Key('color_hex_input')), findsNothing);
  });
}
