import '../data/call_models.dart';

abstract interface class CallRepository {
  Future<CallConnection> create({
    required String workspaceId,
    required List<String> invitees,
    required bool video,
    required String threadId,
    required String title,
  });
  Future<List<CallRoom>> incoming();
  Future<CallConnection> join(CallRoom room);
  Future<CallRoom> state(CallRoom room);
  Future<void> decline(CallRoom room);
  Future<void> end(CallRoom room);
  Future<void> mode(CallRoom room, bool video);
}

class CallException implements Exception {
  const CallException(this.message);
  final String message;
  @override
  String toString() => message;
}
