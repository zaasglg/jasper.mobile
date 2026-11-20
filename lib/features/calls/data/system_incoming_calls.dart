import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/entities/call_room.dart';
import 'call_background_service.dart';

/// Platform UI only. Detection/delivery still belongs to the authenticated app.
class SystemIncomingCalls {
  static const channel = MethodChannel('jospar/incoming_call');
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  void listen(
    Future<void> Function(String action, String id, bool muted) handler,
  ) {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      final data = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      return handler(
        call.method,
        data['id']?.toString() ?? '',
        data['muted'] == true,
      );
    });
  }

  Future<bool> show(CallRoom room) async {
    if (!supported) return false;
    await CallBackgroundService.requestNotifications();
    return await channel.invokeMethod<bool>('show', {
          'id': room.id,
          'name': room.callerName.isEmpty ? 'Входящий звонок' : room.callerName,
          'video': room.video,
        }) ??
        false;
  }

  Future<void> answer(String id) => _send('answer', id);
  Future<void> connected(String id) => _send('connected', id);
  Future<void> end(String id) => _send('end', id);
  Future<void> mute(String id, bool muted) async {
    if (supported) {
      await channel.invokeMethod<void>('mute', {'id': id, 'muted': muted});
    }
  }

  Future<void> _send(String method, String id) async {
    if (supported) await channel.invokeMethod<void>(method, {'id': id});
  }

  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
  }
}
