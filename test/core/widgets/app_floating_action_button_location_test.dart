import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/widgets/app_floating_action_button_location.dart';
import 'package:jospar/features/shell/presentation/widgets/app_bottom_navigation.dart';

void main() {
  for (final safeBottom in [0.0, 34.0]) {
    testWidgets(
      'action stays visible above overlaid navigation, inset $safeBottom',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(bottom: safeBottom),
                viewPadding: EdgeInsets.only(bottom: safeBottom),
              ),
              child: child!,
            ),
            home: Scaffold(
              extendBody: true,
              bottomNavigationBar: AppBottomNavigation(
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home),
                    label: 'Главная',
                  ),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
              body: Builder(
                builder: (context) => Scaffold(
                  floatingActionButtonLocation: AppFloatingActionButtonLocation(
                    context,
                  ),
                  floatingActionButton: FloatingActionButton(
                    key: const Key('action'),
                    onPressed: () => tapped = true,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('action'));
        final navigation = find.byType(AppBottomNavigation);
        expect(
          tester.getRect(button).bottom,
          lessThanOrEqualTo(tester.getRect(navigation).top - 16),
        );
        await tester.tap(button);
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
