import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps an accepted/outgoing Android call alive with a visible notification.
/// It never starts microphone capture or receives calls on its own.
abstract final class CallBackgroundService {
  static const channel = MethodChannel('jospar/call_lifecycle');
  static bool _screenShare = false;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> requestNotifications() async {
    if (!supported) return;
    // Wait for this dialog before requesting microphone/camera permissions.
    // Denying notifications does not prevent a user-initiated foreground call.
    await channel.invokeMethod<bool>('requestNotifications');
  }

  static Future<void> start({required bool camera, bool? screenShare}) async {
    if (!supported) return;
    final projection = screenShare ?? _screenShare;
    await channel.invokeMethod<void>('start', {
      'camera': camera,
      'screenShare': projection,
    });
    _screenShare = projection;
  }

  static Future<void> stop() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('stop');
    } finally {
      _screenShare = false;
    }
  }

  static Future<void> initialize({
    required VoidCallback openCall,
    required Future<void> Function() hangUp,
  }) async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'openCall':
          openCall();
        case 'serviceUnavailable':
        case 'hangUp':
          await hangUp();
      }
    });
    if (await channel.invokeMethod<bool>('consumePendingOpen') == true) {
      openCall();
    }
  }
}
