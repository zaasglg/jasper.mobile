import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jospar/core/auth/auth_session.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:jospar/core/localization/locale_cubit.dart';
import 'package:jospar/core/localization/language_selector.dart';
import 'package:jospar/features/profile/domain/entities/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';

class _Profiles implements ProfileRepository, ProfileLocaleRepository {
  String owner = 'alice', locale = 'kk';
  bool fail = false;
  final updates = <String>[];
  Completer<UserProfile>? pendingSave;
  UserProfile get profile =>
      UserProfile(id: owner, name: 'Имя', email: 'mail', locale: locale);
  @override
  Future<UserProfile> getCurrentUser() async => profile;
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) async => profile;
  @override
  Future<UserProfile> updateLocale(String code) async {
    updates.add(code);
    if (fail) throw StateError('Offline');
    if (pendingSave != null) return pendingSave!.future;
    locale = code;
    return profile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late AuthTokenStorage tokens;
  late _Profiles profiles;
  late AuthSession session;
  String token(String id) =>
      'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.x';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tokens = AuthTokenStorage(const FlutterSecureStorage());
    profiles = _Profiles();
    session = AuthSession();
    await AppTranslations.load();
  });
  LocaleCubit make() =>
      LocaleCubit(profiles, profiles, prefs, tokens, session: session);

  test(
    'Kazakh translation and template substitution use bundled dictionaries',
    () {
      expect(AppTranslations.key('Настройки'), 'm_${_hash('Настройки')}');
      expect(AppTranslations.translate('  Настройки\n', 'kk'), '  Баптаулар\n');
      expect(AppTranslations.translate('Настройки', 'ru'), 'Настройки');
      expect(
        AppTranslations.translate('Название неизвестного проекта', 'kk'),
        'Название неизвестного проекта',
      );
      expect(
        AppTranslations.translate('{p0} из {p1} выполнено', 'kk', {
          'p0': 5,
          'p1': 12,
        }),
        '12 ішінен 5 орындалды',
      );
    },
  );

  test(
    'server profile overrides device default and saves the chosen locale',
    () async {
      await tokens.save(token('alice'));
      final cubit = make();
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.state.error, isNull);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.code, 'kk');
      expect(prefs.getString('ui_locale.alice'), 'kk');
      await cubit.select('ru');
      expect(profiles.updates, ['ru']);
      expect(cubit.state.code, 'ru');
      profiles.fail = true;
      await cubit.select('kk');
      expect(cubit.state.code, 'ru');
      expect(cubit.state.error, isNotNull);
    },
  );

  test('guest choice persists without updating a profile', () async {
    final cubit = make();
    await cubit.select('kk');
    expect(cubit.state.code, 'kk');
    expect(prefs.getString('ui_locale.guest'), 'kk');
    expect(profiles.updates, isEmpty);
    await cubit.close();
    final restored = make();
    expect(restored.state.code, 'kk');
    await restored.close();
  });

  test(
    'account switch during save ignores the old response and clears saving',
    () async {
      await tokens.save(token('alice'));
      final cubit = make();
      addTearDown(cubit.close);
      await cubit.refresh();
      profiles.pendingSave = Completer<UserProfile>();
      final save = cubit.select('ru');
      await Future<void>.delayed(Duration.zero);
      await tokens.save(token('bob'));
      profiles.owner = 'bob';
      profiles.locale = 'ru';
      session.markAuthenticated();
      await Future<void>.delayed(Duration.zero);
      profiles.pendingSave!.complete(
        const UserProfile(id: 'alice', name: '', email: '', locale: 'ru'),
      );
      await save;
      expect(cubit.state.owner, 'bob');
      expect(cubit.state.code, 'ru');
      expect(cubit.state.saving, isFalse);
    },
  );

  testWidgets(
    'selector updates app locale immediately and leaves user text unchanged',
    (tester) async {
      final cubit = make();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocBuilder<LocaleCubit, AppLocaleState>(
          bloc: cubit,
          builder: (context, state) => MaterialApp(
            locale: Locale(state.code),
            supportedLocales: const [Locale('ru'), Locale('kk')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    LanguageSelector(cubit: cubit),
                    Text(tr(context, 'Настройки')),
                    const Text('Настройки', key: Key('user-task-title')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-kk')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(cubit.state.error, isNull);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.code, 'kk');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('kk'),
      );
      expect(
        Localizations.localeOf(
          tester.element(find.byKey(const Key('user-task-title'))),
        ).languageCode,
        'kk',
      );
      expect(find.text('Баптаулар'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('user-task-title'))).data,
        'Настройки',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

String _hash(String s) {
  var hash = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    hash = ((hash ^ unit) * 0x1000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
