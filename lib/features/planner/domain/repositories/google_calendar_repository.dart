import '../../data/models/google_calendar_models.dart';

abstract interface class GoogleCalendarRepository {
  Future<GoogleCalendarStatus> status();
  Future<Uri> authorizationUrl();
  Future<List<GoogleCalendarEvent>> events(
    DateTime start,
    DateTime end, {
    bool includeHolidays = true,
  });
  Future<void> disconnect();
}
