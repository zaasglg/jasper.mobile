import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/push_gateway.dart';

class NativePushGateway implements PushGateway {
  NativePushGateway() {
    if (supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'tokenChanged') {
          _events.add({'kind': 'tokenChanged', 'token': call.arguments});
        } else if (call.method == 'opened' || call.method == 'message') {
          if (call.arguments is Map) {
            _events.add({
              'kind': call.method,
              'data': Map<String, dynamic>.from(call.arguments as Map),
            });
          }
        }
      });
    }
  }
  static const _channel = MethodChannel('jospar/push_notifications');
  static const _permissions = MethodChannel('jospar/call_lifecycle');
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(
    await _channel.invokeMapMethod<String, dynamic>('status') ?? {},
  );
  @override
  Future<String?> token() => _channel.invokeMethod<String>('token');
  @override
  Future<Map<String, dynamic>?> initialMessage() =>
      _channel.invokeMapMethod<String, dynamic>('initialMessage');
  @override
  Future<void> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _channel.invokeMethod<bool>('requestPermission');
    } else {
      await _permissions.invokeMethod<bool>('requestNotifications');
    }
  }

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('settings');
  @override
  Future<void> bindAccount(String userId) =>
      _channel.invokeMethod<void>('bindAccount', {'userId': userId});
  @override
  Future<void> clearAccount() => _channel.invokeMethod<void>('clearAccount');
  @override
  Future<void> deleteToken() => _channel.invokeMethod<void>('deleteToken');
}
