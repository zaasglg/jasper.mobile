import 'package:dio/dio.dart';
import '../../../assistant/data/services/assistant_cancel_token.dart';
import '../../../assistant/domain/entities/assistant_request.dart';
import '../../domain/entities/ai_day_plan_entry.dart';
import '../../domain/repositories/ai_day_plan_repository.dart';
import '../../domain/utils/planner_dates.dart';

class AiDayPlanRepositoryImpl implements AiDayPlanRepository {
  const AiDayPlanRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<AiDayPlanEntry>> suggest({
    required String workspaceId,
    required DateTime day,
    required AssistantRequest request,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        'ai/assistant/day-plan',
        data: {'workspaceId': workspaceId, 'date': plannerDayString(day)},
        options: Options(
          headers: {'X-Workspace-Id': workspaceId},
          receiveTimeout: const Duration(minutes: 1),
        ),
        cancelToken: assistantCancelToken(request),
      );
      final raw = response.data;
      final body = raw is Map && raw['data'] is Map ? raw['data'] : raw;
      if (body is! Map ||
          body['date'] != plannerDayString(day) ||
          body['items'] is! List) {
        throw const FormatException();
      }
      final items = body['items'] as List;
      if (items.length > 5 || items.any((e) => e is! Map<String, dynamic>)) {
        throw const FormatException();
      }
      final entries = items
          .map((e) => AiDayPlanEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (entries.map((e) => e.taskId).toSet().length != entries.length ||
          entries.fold<int>(0, (n, e) => n + e.durationMinutes) > 240) {
        throw const FormatException();
      }
      // Selection and save status are client-owned, never accepted from AI.
      return entries
          .map((e) => e.copyWith(selected: true, saved: false, clearTime: true))
          .toList();
    } on DioException catch (e) {
      throw AiDayPlanException(switch (e.response?.statusCode) {
        404 => 'Для AI-плана дня требуется обновление сервера.',
        401 ||
        403 => 'Нет доступа. Войдите снова или выберите рабочее пространство.',
        429 => 'Слишком много запросов. Попробуйте через минуту.',
        _ => 'Не удалось составить план. Попробуйте ещё раз.',
      });
    } on FormatException {
      throw const AiDayPlanException(
        'AI вернул некорректный план. Попробуйте ещё раз.',
      );
    }
  }
}
