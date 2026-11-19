import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/core/widgets/app_snack_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _preview = bool.fromEnvironment('NOTICE_PREVIEW');
final _capture = GlobalKey();

Future<void> _show(
  WidgetTester tester, {
  AppSnackBarTone tone = AppSnackBarTone.success,
  String message = 'Задача добавлена в ежедневник',
  String? description,
  SnackBarAction? action,
  double textScale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _capture,
      child: MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Ежедневник')),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 1,
            destinations: const [
              NavigationDestination(
                icon: Icon(LucideIcons.house),
                label: 'Главная',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.calendarDays),
                label: 'Ежедневник',
              ),
            ],
          ),
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  appSnackBar(
                    context: context,
                    tone: tone,
                    content: Text(message),
                    description: description,
                    action: action,
                  ),
                ),
                child: const Text('Показать уведомление'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Показать уведомление'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!_preview) return;
    final font = ByteData.sublistView(
      await File('.codex/visual/project-board/Manrope.ttf').readAsBytes(),
    );
    for (final family in [
      'Manrope',
      for (final weight in [400, 500, 600, 700, 800]) 'Manrope_$weight',
    ]) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'success floats above navigation and supports close and automatic dismissal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _show(tester);
      final notice = find.byType(SnackBar);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(
        tester.getRect(notice).bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
      await tester.tap(find.text('Показать уведомление'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long errors and an undo action fit large type above a keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    var undone = 0;
    const message =
        'Не удалось сохранить задачу. Проверьте подключение и попробуйте ещё раз.';
    await _show(
      tester,
      tone: AppSnackBarTone.error,
      message: message,
      textScale: 1.6,
      action: SnackBarAction(label: 'Отменить', onPressed: () => undone++),
    );
    expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(540),
    );
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Отменить'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide notice keeps a readable width and shows optional context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _show(
      tester,
      tone: AppSnackBarTone.info,
      description: 'Подготовить презентацию проекта',
    );
    expect(find.byIcon(LucideIcons.info), findsOneWidget);
    expect(find.text('Подготовить презентацию проекта'), findsOneWidget);
    final card = find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first;
    expect(tester.getSize(card).width, 560);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification visual previews', (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      for (final tone in AppSnackBarTone.values) {
        await _show(
          tester,
          tone: tone,
          message: tone == AppSnackBarTone.error
              ? 'Не удалось сохранить задачу'
              : 'Задача добавлена в ежедневник',
          description: tone == AppSnackBarTone.error
              ? 'Проверьте подключение и попробуйте ещё раз.'
              : 'Подготовить презентацию проекта',
        );
        final boundary =
            _capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/notice-preview').create(recursive: true);
          await File(
            'build/notice-preview/${tone.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      }
    } finally {
      debugDisableShadows = previousShadows;
    }
  }, skip: !_preview);
}
