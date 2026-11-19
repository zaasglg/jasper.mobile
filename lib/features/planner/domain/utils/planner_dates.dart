// Display using the device zone; persist instants in UTC.
DateTime plannerLocal(DateTime value) => value.toLocal();
DateTime plannerNow() => plannerLocal(DateTime.now());
DateTime plannerDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String plannerDayString(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime plannerInstant(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute).toUtc();
bool samePlannerDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String plannerClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
