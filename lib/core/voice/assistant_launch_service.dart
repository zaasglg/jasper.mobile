import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

// Preserve Siri and widget requests through splash/authentication, then open
// the assistant once the authenticated shell is ready.
class AssistantLaunchService {
  AssistantLaunchService(
    this._router, {
    MethodChannel channel = const MethodChannel('jospar/assistant_launch'),
  }) : _channel = channel;
  final GoRouter _router;
  final MethodChannel _channel;
  final _repeatedLaunches = StreamController<void>.broadcast();
  Stream<void> get repeatedLaunches => _repeatedLaunches.stream;
  final _textLaunches = StreamController<void>.broadcast();
  Stream<void> get textLaunches => _textLaunches.stream;
  bool _voice = true;
  bool _pending = false;
  bool _scheduled = false;
  void requestLaunch({bool voice = true}) {
    _voice = voice;
    _pending = true;
    _tryOpen();
  }

  void dispose() {
    _router.routerDelegate.removeListener(_tryOpen);
    _channel.setMethodCallHandler(null);
    _repeatedLaunches.close();
    _textLaunches.close();
  }

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openAssistant') {
        _voice = true;
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
      if (!_pending && initial) _voice = true;
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
    if (path == '/' || path == '/login' || path == '/splash' || path.isEmpty) {
      return;
    }
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
      if (current == '/' ||
          current == '/login' ||
          current == '/splash' ||
          current.isEmpty) {
        return;
      }
      _pending = false;
      if (current == '/assistant') {
        (_voice ? _repeatedLaunches : _textLaunches).add(null);
      } else {
        unawaited(
          _router.push(
            _voice ? '/assistant?voice=true' : '/assistant?keyboard=true',
          ),
        );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
