import 'features/notifications/data/mobile_push_registration.dart';
import 'features/notifications/presentation/push_cubit.dart';
import 'features/notifications/presentation/push_launch_service.dart';
import 'features/calls/data/call_background_service.dart';
import 'features/calls/presentation/call_cubit.dart';
import 'features/calls/presentation/calls_host.dart';
import 'core/voice/assistant_launch_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/inbox/data/services/inbox_home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // AVPlayer cannot decode WebM notes created by the web client.
  // Use the bundled decoder on iOS, retaining the video_player interface.
  VideoPlayerMediaKit.ensureInitialized(iOS: true);
  await initServiceLocator();
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
    unawaited(_listenForInboxWidgetLaunches());
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

Future<void> _listenForInboxWidgetLaunches() async {
  Uri? pending;
  void tryOpen() {
    final uri = pending;
    if (uri == null) return;
    final path = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (path == '/' || path == '/splash' || path == '/login') return;
    pending = null;
    appRouter.go(
      uri.queryParameters['action'] == 'add'
          ? '/inbox?compose=${DateTime.now().microsecondsSinceEpoch}'
          : '/inbox',
    );
  }

  appRouter.routerDelegate.addListener(tryOpen);
  void openInbox(Uri? uri) {
    if (uri?.scheme == 'jospar' && uri?.host == 'inbox') {
      pending = uri;
      tryOpen();
    }
  }

  try {
    openInbox(await HomeWidget.initiallyLaunchedFromHomeWidget());
    await _widgetLinkSubscription?.cancel();
    _widgetLinkSubscription = HomeWidget.widgetClicked.listen(openInbox);
  } catch (_) {
    // Home-screen widgets are unavailable on desktop and test platforms.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'josparbee',
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: [
        const Locale('en'),
        for (final language in kMaterialSupportedLanguages)
          if (language != 'en') Locale(language),
      ],
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
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
