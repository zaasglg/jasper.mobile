import 'package:equatable/equatable.dart';

class PushNotificationData extends Equatable {
  const PushNotificationData({this.data = const {}});
  factory PushNotificationData.fromJson(Map<String, dynamic> json) =>
      PushNotificationData(
        data: {
          for (final entry in json.entries)
            if (entry.value is String) entry.key: entry.value as String,
        },
      );
  final Map<String, String> data;
  String get id => data['messageId'] ?? '';
  String get route {
    if (data['type'] == 'reminder' && data['plannerItemId']?.isNotEmpty == true) {
      return '/planner';
    }
    final task = data['taskId'];
    if (task != null && task.trim().isNotEmpty) {
      return '/tasks/${Uri.encodeComponent(task)}';
    }
    final thread = data['threadId'];
    if (thread != null && thread.trim().isNotEmpty) {
      return Uri(
        pathSegments: ['', 'messenger', thread],
        queryParameters: {
          if (data['chatMessageId']?.isNotEmpty == true)
            'messageId': data['chatMessageId']!,
        },
      ).toString();
    }
    // Never navigate to arbitrary URLs supplied in a notification.
    return '/activity/notifications';
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
  PushNotificationData copyWith({Map<String, String>? data}) =>
      PushNotificationData(data: data ?? this.data);
  @override
  List<Object?> get props => [data];
}
