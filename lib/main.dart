import 'features/notifications/presentation/notification_preferences_cubit.dart';
import 'core/localization/locale_cubit.dart';
import 'core/localization/locale_sync.dart';
import 'core/theme/theme_cubit.dart';
import 'features/notifications/data/mobile_push_registration.dart';
import 'features/notifications/presentation/push_cubit.dart';
import 'features/notifications/presentation/push_launch_service.dart';
import 'features/calls/data/call_background_service.dart';
import 'features/calls/presentation/call_cubit.dart';
import 'features/calls/presentation/calls_host.dart';
import 'core/voice/assistant_launch_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/inbox/presentation/cubit/inbox_cubit.dart';
import 'features/inbox/presentation/screens/inbox_quick_add_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/inbox/data/services/inbox_home_widget_service.dart';

@pragma('vm:entry-point')
Future<void> inboxWidgetMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initServiceLocator();
  sl<NotificationPreferencesCubit>().start();
  await InboxHomeWidgetService.initialize();
  runApp(
    LocaleSync(
      cubit: sl<LocaleCubit>(),
      child: BlocBuilder<LocaleCubit, AppLocaleState>(
        bloc: sl<LocaleCubit>(),
        builder: (context, language) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: sl<ThemeCubit>().state,
          locale: Locale(language.code),
          supportedLocales: const [Locale('ru'), Locale('kk')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          debugShowCheckedModeBanner: false,
          home: BlocProvider(
            create: (_) => sl<InboxCubit>(),
            child: InboxQuickAddScreen(
              overlay: true,
              onClose: () {
                SystemNavigator.pop();
              },
            ),
          ),
        ),
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VideoPlayerMediaKit.ensureInitialized(iOS: true);
  await initServiceLocator();
  sl<NotificationPreferencesCubit>().start();
  await InboxHomeWidgetService.initialize();
  sl.registerSingleton<AssistantLaunchService>(
    AssistantLaunchService(appRouter),
  );
  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      PushLaunchService(
        appRouter,
        sl(),
        sl<PushCubit>(),
        registration: MobilePushRegistration(sl(), sl(), sl<PushCubit>()),
      ).initialize(),
    );
    unawaited(_listenForHomeWidgetLaunches());
    unawaited(sl<AssistantLaunchService>().initialize());
    unawaited(
      CallBackgroundService.initialize(
        openCall: () {
          if (sl<CallCubit>().state.busy &&
              appRouter.routerDelegate.currentConfiguration.uri.path !=
                  '/call') {
            appRouter.push('/call');
          }
        },
        hangUp: () => sl<CallCubit>().finish(),
      ),
    );
  });
}

StreamSubscription<Uri?>? _widgetLinkSubscription;

Future<void> _listenForHomeWidgetLaunches() async {
  Uri? pending;
  void tryOpen() {
    final uri = pending;
    if (uri == null) return;
    final path = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (path == '/' || path == '/splash' || path == '/login') return;
    pending = null;
    appRouter.go(
      uri.queryParameters['action'] == 'add' ? '/inbox/quick-add' : '/inbox',
    );
  }

  appRouter.routerDelegate.addListener(tryOpen);
  void openWidget(Uri? uri) {
    if (uri?.scheme == 'jospar' && uri?.host == 'assistant') {
      sl<AssistantLaunchService>().requestLaunch(voice: false);
      return;
    }
    if (uri?.scheme == 'jospar' && uri?.host == 'inbox') {
      pending = uri;
      tryOpen();
    }
  }

  try {
    openWidget(await HomeWidget.initiallyLaunchedFromHomeWidget());
    await _widgetLinkSubscription?.cancel();
    _widgetLinkSubscription = HomeWidget.widgetClicked.listen(openWidget);
  } catch (_) {
    // Home-screen widgets are unavailable on desktop and test platforms.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LocaleSync(
      cubit: sl<LocaleCubit>(),
      child: BlocBuilder<LocaleCubit, AppLocaleState>(
        bloc: sl<LocaleCubit>(),
        builder: (context, language) => BlocBuilder<ThemeCubit, ThemeMode>(
          bloc: sl<ThemeCubit>(),
          builder: (context, mode) => MaterialApp.router(
            title: 'josparbee',
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            locale: Locale(language.code),
            supportedLocales: const [Locale('ru'), Locale('kk')],
            builder: (context, child) => CallsHost(
              routeChanges: appRouter.routerDelegate,
              onOpen: () {
                if (appRouter
                        .routerDelegate
                        .currentConfiguration
                        .last
                        .matchedLocation !=
                    '/call') {
                  appRouter.push('/call');
                }
              },
              onCallPage: () =>
                  appRouter
                      .routerDelegate
                      .currentConfiguration
                      .last
                      .matchedLocation ==
                  '/call',
              child: child ?? const SizedBox(),
            ),
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter,
          ),
        ),
      ),
    );
  }
}
