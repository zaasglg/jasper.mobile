import 'package:equatable/equatable.dart';
import '../../domain/utils/planner_dates.dart';
import 'planner_item_model.dart';

class GoogleCalendarStatus extends Equatable {
  const GoogleCalendarStatus({this.connected = false, this.canWrite = false});
  factory GoogleCalendarStatus.fromJson(Map<String, dynamic> json) =>
      GoogleCalendarStatus(
        connected: json['connected'] == true,
        canWrite: json['canWrite'] == true,
      );
  final bool connected, canWrite;
  Map<String, dynamic> toJson() => {
    'connected': connected,
    'canWrite': canWrite,
  };
  GoogleCalendarStatus copyWith({bool? connected, bool? canWrite}) =>
      GoogleCalendarStatus(
        connected: connected ?? this.connected,
        canWrite: canWrite ?? this.canWrite,
      );
  @override
  List<Object?> get props => [connected, canWrite];
}

class GoogleCalendarEvent extends Equatable {
  const GoogleCalendarEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.allDay = false,
    this.holiday = false,
    this.calendarId = '',
  });
  factory GoogleCalendarEvent.fromJson(Map<String, dynamic> json) =>
      GoogleCalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Событие Google',
        startsAt: json['startsAt'] as String,
        endsAt: json['endsAt'] as String?,
        allDay: json['allDay'] == true,
        holiday: json['holiday'] == true,
        calendarId: json['calendarId'] as String? ?? '',
      );
  final String id, title, startsAt, calendarId;
  final String? endsAt;
  final bool allDay, holiday;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'allDay': allDay,
    'holiday': holiday,
    'calendarId': calendarId,
  };
  GoogleCalendarEvent copyWith({
    String? id,
    String? title,
    String? startsAt,
    String? endsAt,
    bool? allDay,
    bool? holiday,
    String? calendarId,
  }) => GoogleCalendarEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    allDay: allDay ?? this.allDay,
    holiday: holiday ?? this.holiday,
    calendarId: calendarId ?? this.calendarId,
  );

  /// Split multi-day events at local midnight; Google's all-day end is exclusive.
  List<PlannerItemModel> entries(DateTime rangeStart, DateTime rangeEnd) {
    final parsed = DateTime.tryParse(startsAt);
    if (parsed == null) return [];
    final start = allDay ? plannerInstant(parsed, 0, 0) : parsed.toUtc();
    final parsedEnd = DateTime.tryParse(endsAt ?? '');
    final end = parsedEnd == null
        ? start.add(Duration(minutes: allDay ? 1440 : 30))
        : allDay
        ? plannerInstant(parsedEnd, 0, 0)
        : parsedEnd.toUtc();
    if (!end.isAfter(start)) return [];
    final result = <PlannerItemModel>[];
    for (
      var day = plannerDate(rangeStart);
      day.isBefore(rangeEnd);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final midnight = plannerInstant(day, 0, 0);
      final next = midnight.add(const Duration(days: 1));
      if (!start.isBefore(next) || !end.isAfter(midnight)) continue;
      final sliceStart = start.isAfter(midnight) ? start : midnight;
      final sliceEnd = end.isBefore(next) ? end : next;
      result.add(
        PlannerItemModel(
          id: '$id:${day.toIso8601String()}',
          title: title,
          projectName: 'Google Календарь',
          scheduledAt: sliceStart,
          durationMinutes: sliceEnd
              .difference(sliceStart)
              .inMinutes
              .clamp(1, 1440),
          external: true,
          allDay: allDay,
        ),
      );
    }
    return result;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    startsAt,
    endsAt,
    allDay,
    holiday,
    calendarId,
  ];
}
