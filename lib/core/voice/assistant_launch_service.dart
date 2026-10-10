import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

// Siri launches can arrive before splash/authentication completes. Preserve the
// request and navigate only once the authenticated shell is ready.
class AssistantLaunchService {
  AssistantLaunchService(
    this._router, {
    MethodChannel channel = const MethodChannel('jospar/assistant_launch'),
  }) : _channel = channel;
  final GoRouter _router;
  final MethodChannel _channel;
  final _repeatedLaunches = StreamController<void>.broadcast();
  Stream<void> get repeatedLaunches => _repeatedLaunches.stream;
  bool _pending = false;
  bool _scheduled = false;
  void requestLaunch() {
    _pending = true;
    _tryOpen();
  }

  void dispose() {
    _router.routerDelegate.removeListener(_tryOpen);
    _channel.setMethodCallHandler(null);
    _repeatedLaunches.close();
  }

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openAssistant') {
        _pending = true;
        try {
          await _channel.invokeMethod<bool>('consumePendingLaunch');
        } on PlatformException {
          /* Keep the foreground launch request. */
        }
        _tryOpen();
      }
    });
    _router.routerDelegate.addListener(_tryOpen);
    try {
      final initial =
          await _channel.invokeMethod<bool>('consumePendingLaunch') ?? false;
      _pending = _pending || initial;
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
    _tryOpen();
  }

  void _tryOpen() {
    if (!_pending || _scheduled) return;
    final path =
        _router
            .routerDelegate
            .currentConfiguration
            .lastOrNull
            ?.matchedLocation ??
        '';
    if (path == '/login' || path == '/splash' || path.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final current =
          _router
              .routerDelegate
              .currentConfiguration
              .lastOrNull
              ?.matchedLocation ??
          '';
      if (current == '/login' || current == '/splash' || current.isEmpty) {
        return;
      }
      _pending = false;
      if (current == '/assistant') {
        _repeatedLaunches.add(null);
      } else {
        unawaited(_router.push('/assistant?voice=true'));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
