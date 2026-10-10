import '../../data/models/assistant_message_model.dart';

abstract interface class AssistantRepository {
  Future<AssistantMessageModel> chat({
    required String workspaceId,
    required List<AssistantMessageModel> messages,
  });
}

class AssistantException implements Exception {
  const AssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}
