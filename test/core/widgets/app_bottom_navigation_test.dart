import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/shell/presentation/widgets/app_bottom_navigation.dart';

void main() {
  for (final width in [280.0, 320.0, 390.0, 600.0]) {
    testWidgets('navigation labels fit at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              selectedIndex: 0,
              onSelected: (index) => selected = index,
              destinations: [
                for (final label in [
                  'Дашборд',
                  'Проекты',
                  'Мессенджер',
                  'Инбокс',
                  'Ежедневник',
                ])
                  NavigationDestination(
                    icon: const Icon(Icons.circle_outlined),
                    label: label,
                  ),
              ],
            ),
          ),
        ),
      );
      for (final label in ['Мессенджер', 'Ежедневник']) {
        final bounds = tester.getRect(find.text(label));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(width));
        expect(bounds.height, lessThan(24));
      }
      await tester.tap(find.byKey(const ValueKey('navigation-tab-2')));
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
