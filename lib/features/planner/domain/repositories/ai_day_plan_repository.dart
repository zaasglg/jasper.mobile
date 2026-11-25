import '../../../assistant/domain/entities/assistant_request.dart';
import '../entities/ai_day_plan_entry.dart';

abstract interface class AiDayPlanRepository {
  Future<List<AiDayPlanEntry>> suggest({
    required String workspaceId,
    required DateTime day,
    required AssistantRequest request,
  });
}

class AiDayPlanException implements Exception {
  const AiDayPlanException(this.message);
  final String message;
  @override
  String toString() => message;
}
