import '../entities/assistant_request.dart';
import '../entities/assistant_attachment.dart';
import '../entities/assistant_message_model.dart';

abstract interface class AssistantRepository {
  Future<AssistantMessageModel> chat({
    required String workspaceId,
    required List<AssistantMessageModel> messages,
    List<String> images = const [],
    List<AssistantAttachment> attachments = const [],
    String? currentProjectId,
    AssistantRequest? request,
  });
}

class AssistantException implements Exception {
  const AssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}
