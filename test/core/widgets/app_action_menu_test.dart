import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/widgets/app_action_menu.dart';

void main() {
  testWidgets('disabled item cannot select, enabled item returns typed value', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppActionMenuButton<int>(
            title: 'Действия',
            tooltip: 'Меню',
            groups: const [
              [
                AppMenuAction(
                  value: 1,
                  label: 'Недоступно',
                  icon: Icons.lock,
                  enabled: false,
                ),
                AppMenuAction(
                  value: 2,
                  label: 'Выбрать',
                  icon: Icons.check,
                  selected: true,
                ),
              ],
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Недоступно'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byType(AppActionSheet<int>), findsOneWidget);
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(find.byType(AppActionSheet<int>), findsNothing);
  });

  testWidgets('cancel and barrier dismiss without invoking the action', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppActionMenuButton<String>(
            title: 'Действия',
            tooltip: 'Меню',
            groups: const [
              [
                AppMenuAction(
                  value: 'delete',
                  label: 'Удалить',
                  icon: Icons.delete,
                  destructive: true,
                ),
              ],
            ],
            onSelected: (_) {
              calls++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(AppActionSheet<String>), findsNothing);
  });

  testWidgets('long menu scrolls with large text while cancel stays visible', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: AppActionMenuButton<int>(
            title: 'Длинное название задачи для небольшого экрана',
            tooltip: 'Меню',
            groups: [
              [
                for (var i = 0; i < 30; i++)
                  AppMenuAction(
                    value: i,
                    label: 'Действие $i',
                    icon: Icons.edit,
                  ),
              ],
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Меню'));
    await tester.pumpAndSettle();
    final cancel = tester.getRect(find.text('Отмена'));
    expect(cancel.bottom, lessThanOrEqualTo(568));
    await tester.ensureVisible(find.text('Действие 29'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Отмена')), cancel);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });
}
