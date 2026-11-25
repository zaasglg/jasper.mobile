import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jospar/core/theme/theme_cubit.dart';
import 'package:jospar/core/theme/theme_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/auth/domain/entities/login_request.dart';
import 'package:jospar/features/auth/domain/repositories/auth_repository.dart';
import 'package:jospar/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/screens/profile_screen.dart';

class _ProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async => const UserProfile(
    id: '1',
    name: 'Ермахан',
    email: 'yermekhan.00@gmail.com',
    role: 'SUPER_ADMIN',
  );

  @override
  Future<UserProfile> updateAvatar(String avatarUrl) async {
    return (await getCurrentUser()).copyWith(avatarUrl: avatarUrl);
  }
}

class _AuthRepository implements AuthRepository {
  @override
  Future<String> login(LoginRequest request) async => 'token';

  @override
  Future<void> logout() async {}
}

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await sl.reset();
    sl.registerFactory<ProfileCubit>(() => ProfileCubit(_ProfileRepository()));
    sl.registerFactory<AuthCubit>(() => AuthCubit(_AuthRepository()));
  });

  tearDown(() => sl.reset());

  testWidgets('compact theme row opens choices and closes after saving', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cubit = ThemeCubit(preferences);
    sl.registerSingleton<ThemeCubit>(cubit, dispose: (value) => value.close());
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: _goldenTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('profile_theme_button'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.text('Как на устройстве'), findsOneWidget);
    expect(find.byType(ThemeSelector), findsNothing);
    expect(tester.getSize(row).height, lessThan(100));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSelector), findsOneWidget);
    expect(tester.getSize(find.byType(ThemeSelector)).height, lessThan(340));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/profile_theme_selector.png'),
    );
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSelector), findsNothing);
    expect(find.text('Тёмная'), findsOneWidget);
    expect(cubit.state, ThemeMode.dark);
    expect(preferences.getString(ThemeCubit.preferenceKey), 'dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile layout stays usable on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1040);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: _goldenTheme(), home: const ProfileScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ермахан'), findsNWidgets(2));
    expect(find.text('Суперадмин'), findsOneWidget);
    expect(
      find.byKey(const Key('profile_change_photo_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profile_copy_email_button')), findsOneWidget);
    expect(find.text('Голосовой помощник'), findsOneWidget);
    expect(find.byKey(const Key('settings-siri-help')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/profile_screen.png'),
    );
  });

  testWidgets('profile remains scrollable with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _goldenTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile_logout_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_logout_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ThemeData _goldenTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
  );
  return base.copyWith(
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    ),
  );
}
