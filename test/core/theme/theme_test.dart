import 'package:jospar/core/widgets/app_form_surface.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/theme/theme_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/core/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to system and restores a persisted choice', () async {
    final preferences = await SharedPreferences.getInstance();
    final cubit = ThemeCubit(preferences);
    expect(cubit.state, ThemeMode.system);
    await cubit.select(ThemeMode.dark);
    expect(cubit.state, ThemeMode.dark);
    final restored = ThemeCubit(preferences);
    expect(restored.state, ThemeMode.dark);
    await restored.select(ThemeMode.system);
    expect(ThemeCubit(preferences).state, ThemeMode.system);
    await cubit.close();
    await restored.close();
  });

  test('rapid choices persist the last selection, including system', () async {
    final preferences = await SharedPreferences.getInstance();
    final cubit = ThemeCubit(preferences);
    await Future.wait([
      cubit.select(ThemeMode.dark),
      cubit.select(ThemeMode.light),
      cubit.select(ThemeMode.system),
    ]);
    expect(cubit.state, ThemeMode.system);
    expect(preferences.getString(ThemeCubit.preferenceKey), 'system');
    await cubit.close();
  });

  test(
    'storage failure does not block appearance and same choice retries',
    () async {
      final preferences = _ControlledPreferences();
      final cubit = ThemeCubit(preferences);
      addTearDown(cubit.close);
      await expectLater(cubit.select(ThemeMode.dark), throwsStateError);
      expect(cubit.state, ThemeMode.dark);
      expect(preferences.writes, 1);
      preferences.fail = false;
      await cubit.select(ThemeMode.dark);
      expect(preferences.saved, 'dark');
      expect(preferences.writes, 2);
      expect(ThemeCubit(preferences).state, ThemeMode.dark);
    },
  );

  test('unknown saved values fall back to system', () async {
    SharedPreferences.setMockInitialValues({
      ThemeCubit.preferenceKey: 'invalid',
    });
    final cubit = ThemeCubit(await SharedPreferences.getInstance());
    expect(cubit.state, ThemeMode.system);
    await cubit.close();
  });

  testWidgets(
    'selection updates appearance and system brightness is respected',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final cubit = ThemeCubit(await SharedPreferences.getInstance());
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocBuilder<ThemeCubit, ThemeMode>(
          bloc: cubit,
          builder: (context, mode) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: Scaffold(body: ThemeSelector(cubit: cubit)),
          ),
        ),
      );
      BuildContext context() => tester.element(find.byType(ThemeSelector));
      expect(Theme.of(context()).brightness, Brightness.light);
      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();
      expect(cubit.state, ThemeMode.dark);
      expect(Theme.of(context()).brightness, Brightness.dark);
      expect(AppColors.of(context()).ink, const AppPalette(true).ink);
      await tester.tap(find.text('Системная'));
      await tester.pumpAndSettle();
      expect(Theme.of(context()).brightness, Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(Theme.of(context()).brightness, Brightness.dark);
      await tester.tap(find.text('Светлая'));
      await tester.pumpAndSettle();
      expect(Theme.of(context()).brightness, Brightness.light);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing sheets retain dark input surfaces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: AppFormSurface(child: TextField())),
      ),
    );
    final context = tester.element(find.byType(TextField));
    expect(
      Theme.of(context).inputDecorationTheme.fillColor,
      const AppPalette(true).subtleSurface,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark appearance selector stays readable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = ThemeCubit(await SharedPreferences.getInstance());
    await cubit.select(ThemeMode.dark);
    sl.registerSingleton<ThemeCubit>(cubit);
    addTearDown(() async {
      await sl.unregister<ThemeCubit>();
      await cubit.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: ThemeSelector(cubit: cubit)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Тёмная'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('dark primary and secondary text have accessible surface contrast', () {
    const colors = AppPalette(true);
    double contrast(Color foreground, Color background) {
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      return (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05));
    }

    for (final surface in [
      colors.canvas,
      colors.subtleSurface,
      colors.badgeSurface,
      colors.outgoingMessage,
    ]) {
      expect(contrast(colors.ink, surface), greaterThanOrEqualTo(4.5));
      expect(contrast(colors.muted, surface), greaterThanOrEqualTo(4.5));
    }
  });
}

class _ControlledPreferences implements SharedPreferences {
  bool fail = true;
  int writes = 0;
  String? saved;
  @override
  String? getString(String key) => saved;
  @override
  Future<bool> setString(String key, String value) async {
    writes++;
    if (fail) return false;
    saved = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
