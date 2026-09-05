import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/inbox/data/services/inbox_home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initServiceLocator();
  await InboxHomeWidgetService.initialize();
  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_listenForInboxWidgetLaunches());
  });
}

StreamSubscription<Uri?>? _widgetLinkSubscription;

Future<void> _listenForInboxWidgetLaunches() async {
  void openInbox(Uri? uri) {
    if (uri?.scheme == 'jospar' && uri?.host == 'inbox') {
      appRouter.go('/inbox');
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
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
