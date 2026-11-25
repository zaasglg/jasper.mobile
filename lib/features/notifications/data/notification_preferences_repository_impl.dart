import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/notification_preferences_repository.dart';

class NotificationPreferencesRepositoryImpl
    implements NotificationPreferencesRepository {
  NotificationPreferencesRepositoryImpl(this.preferences, this.dio);
  final SharedPreferences preferences;
  final Dio dio;
  static const _channel = MethodChannel('jospar/push_notifications');
  @override
  NotificationPreferences read(String owner) {
    try {
      final raw = preferences.getString('notifications.$owner');
      if (raw != null) {
        return NotificationPreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {
      /* Invalid cache falls back to defaults. */
    }
    return const NotificationPreferences();
  }

  @override
  Future<void> save(String owner, NotificationPreferences value) async {
    if (!await preferences.setString(
      'notifications.$owner',
      jsonEncode(value.toJson()),
    )) {
      throw StateError('Preferences were not saved');
    }
  }

  @override
  Future<String> applyNative(
    String owner,
    Map<String, dynamic> preferences,
  ) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'setPreferences',
      {'userId': owner, 'preferences': preferences},
    );
    final zone = response?['timeZone'];
    if (zone is! String || zone.isEmpty) {
      throw StateError('Missing device time zone');
    }
    return zone;
  }

  @override
  Future<void> synchronize(
    String jwt,
    String deviceToken,
    Map<String, dynamic> preferences,
  ) async {
    final response = await dio.put<dynamic>(
      'push/mobile/preferences',
      data: {'token': deviceToken, 'preferences': preferences},
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );
    if (response.data is! Map || response.data['saved'] != true) {
      throw StateError('Unconfirmed notification settings');
    }
  }
}
