import 'package:dio/dio.dart';
import '../../domain/repositories/google_calendar_repository.dart';
import '../../domain/repositories/planner_repository.dart';
import '../models/google_calendar_models.dart';

class GoogleCalendarRepositoryImpl implements GoogleCalendarRepository {
  const GoogleCalendarRepositoryImpl(this._dio);
  final Dio _dio;
  Future<T> _request<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException {
      throw const PlannerException(
        'Не удалось обновить Google Календарь. Проверьте подключение и повторите попытку.',
      );
    }
  }

  @override
  Future<GoogleCalendarStatus> status() => _request(
    () async => GoogleCalendarStatus.fromJson(
      Map<String, dynamic>.from(
        (await _dio.get<dynamic>('google-drive/calendar/status')).data as Map,
      ),
    ),
  );
  @override
  Future<Uri> authorizationUrl() => _request(() async {
    final response = await _dio.get<dynamic>('google-drive/auth');
    final uri = Uri.tryParse((response.data as Map)['url']?.toString() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'accounts.google.com') {
      throw const PlannerException(
        'Сервер вернул некорректную ссылку подключения Google.',
      );
    }
    return uri;
  });
  @override
  Future<void> disconnect() => _request(() async {
    await _dio.delete<dynamic>('google-drive/disconnect');
  });
  @override
  Future<List<GoogleCalendarEvent>> events(
    DateTime start,
    DateTime end, {
    bool includeHolidays = true,
  }) => _request(() async {
    final result = <String, GoogleCalendarEvent>{};
    final seen = <String>{};
    String? cursor;
    do {
      final response = await _dio.get<dynamic>(
        'google-drive/calendar/events',
        queryParameters: {
          'timeMin': start.toUtc().toIso8601String(),
          'timeMax': end.toUtc().toIso8601String(),
          'includeHolidays': includeHolidays,
          'take': 50,
          'pageToken': ?cursor,
        },
      );
      final data = response.data as Map;
      for (final raw in data['items'] as List) {
        final event = GoogleCalendarEvent.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        result[event.id] = event;
      }
      cursor = data['nextPageToken'] as String?;
      if (cursor != null && !seen.add(cursor)) {
        throw const PlannerException(
          'Не удалось загрузить следующую страницу Google Календаря.',
        );
      }
    } while (cursor != null);
    return result.values.toList();
  });
}
