import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/core/widgets/app_dialog.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'archive uses the shared white surface and an explicit purple action',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppConfirmation(
                    context,
                    'Архивировать проект?',
                    'Вы сможете восстановить его из архива.',
                    confirmLabel: 'Архивировать',
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        Colors.white,
      );
      final confirm = find.widgetWithText(FilledButton, 'Архивировать');
      final style = Theme.of(tester.element(confirm)).filledButtonTheme.style!;
      expect(style.backgroundColor!.resolve({}), AppColors.accent);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result, true);
      expect(find.byType(AppDialog), findsNothing);
    },
  );
  testWidgets(
    'destructive actions are red and cancel or barrier dismissal never confirms',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppConfirmation(
                    context,
                    'Удалить задачу?',
                    'Это действие нельзя отменить.',
                    confirmLabel: 'Удалить',
                    destructive: true,
                  );
                },
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Удалить');
      expect(
        Theme.of(
          tester.element(confirm),
        ).filledButtonTheme.style!.backgroundColor!.resolve({}),
        AppColors.error,
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(result, false);
      result = null;
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, false);
    },
  );
  testWidgets(
    'long text, large type and keyboard stay scrollable on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
              viewInsets: const EdgeInsets.only(bottom: 210),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppConfirmation(
                  context,
                  'Архивировать большой проект?',
                  List.filled(
                    8,
                    'Проект можно восстановить из архива.',
                  ).join(' '),
                  confirmLabel: 'Архивировать',
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final confirm = find.widgetWithText(FilledButton, 'Архивировать');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'disabled actions cannot activate and reduced motion suppresses press scaling',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: AppDialog(
              title: const Text('Изменить'),
              actions: [
                TextButton(onPressed: null, child: const Text('Недоступно')),
                FilledButton(
                  onPressed: () => calls++,
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Недоступно'));
      expect(calls, 0);
      final gesture = await tester.startGesture(
        tester.getCenter(find.widgetWithText(FilledButton, 'Сохранить')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester
            .widgetList<AnimatedScale>(find.byType(AnimatedScale))
            .every((scale) => scale.scale == 1),
        true,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
