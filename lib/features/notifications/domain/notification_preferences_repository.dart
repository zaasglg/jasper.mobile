import 'entities/notification_preferences.dart';

abstract interface class NotificationPreferencesRepository {
  NotificationPreferences read(String owner);
  Future<void> save(String owner, NotificationPreferences value);
  Future<String> applyNative(String owner, Map<String, dynamic> preferences);
  Future<void> synchronize(
    String jwt,
    String deviceToken,
    Map<String, dynamic> preferences,
  );
}
