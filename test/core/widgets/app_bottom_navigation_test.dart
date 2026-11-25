import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/shell/presentation/widgets/app_bottom_navigation.dart';

void main() {
  for (final width in [280.0, 320.0, 390.0, 600.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('navigation labels fit width $width and scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
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
          final tab = find.ancestor(
            of: find.text(label),
            matching: find.byKey(
              ValueKey('navigation-tab-${label == 'Мессенджер' ? 2 : 4}'),
            ),
          );
          final tabBounds = tester.getRect(tab);
          expect(bounds.left, greaterThanOrEqualTo(tabBounds.left));
          expect(bounds.right, lessThanOrEqualTo(tabBounds.right));
          expect(bounds.bottom, lessThanOrEqualTo(tabBounds.bottom));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.widget<Text>(find.text(label)).maxLines, 1);
          expect(tester.widget<Text>(find.text(label)).softWrap, isFalse);
          expect(
            tester.widget<Text>(find.text(label)).overflow,
            TextOverflow.visible,
          );
        }
        final iconCenters = [
          for (var i = 0; i < 5; i++)
            tester
                .getCenter(
                  find.descendant(
                    of: find.byKey(ValueKey('navigation-tab-$i')),
                    matching: find.byType(Icon),
                  ),
                )
                .dy,
        ];
        expect(iconCenters.toSet().length, 1);
        await tester.tap(find.byKey(const ValueKey('navigation-tab-2')));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
