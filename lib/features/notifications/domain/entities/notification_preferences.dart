import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.messages = true,
    this.mentions = true,
    this.deadlines = true,
    this.quietEnabled = false,
    this.quietStart = 1320,
    this.quietEnd = 480,
  });
  final bool messages, mentions, deadlines, quietEnabled;
  final int quietStart, quietEnd;
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    int minute(String key, int fallback) =>
        json[key] is int && (json[key] as int) >= 0 && (json[key] as int) < 1440
        ? json[key] as int
        : fallback;
    return NotificationPreferences(
      messages: json['messages'] != false,
      mentions: json['mentions'] != false,
      deadlines: json['deadlines'] != false,
      quietEnabled: json['quietEnabled'] == true,
      quietStart: minute('quietStart', 1320),
      quietEnd: minute('quietEnd', 480),
    );
  }
  Map<String, dynamic> toJson() => {
    'messages': messages,
    'mentions': mentions,
    'deadlines': deadlines,
    'quietEnabled': quietEnabled,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
  };
  NotificationPreferences copyWith({
    bool? messages,
    bool? mentions,
    bool? deadlines,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
  }) => NotificationPreferences(
    messages: messages ?? this.messages,
    mentions: mentions ?? this.mentions,
    deadlines: deadlines ?? this.deadlines,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
  );
  bool isQuiet(DateTime local) {
    if (!quietEnabled) return false;
    final minute = local.hour * 60 + local.minute;
    if (quietStart == quietEnd) return true;
    return quietStart < quietEnd
        ? minute >= quietStart && minute < quietEnd
        : minute >= quietStart || minute < quietEnd;
  }

  bool allows(String type, DateTime local) {
    if (type == 'call') return true;
    if (isQuiet(local)) return false;
    return switch (type) {
      'message' => messages,
      'mention' => mentions,
      'deadline' || 'reminder' || 'planner' => deadlines,
      _ => true,
    };
  }

  @override
  List<Object?> get props => [
    messages,
    mentions,
    deadlines,
    quietEnabled,
    quietStart,
    quietEnd,
  ];
}
