import '../data/collaboration_models.dart';

abstract interface class CollaborationRepository {
  Future<ManagedSpace> getSpace(SpaceKind kind, String id);
  Future<void> updateSpace(
    SpaceKind kind,
    String id,
    Map<String, dynamic> changes,
  );
  Future<List<ManagedSpace>> archived(SpaceKind kind, {String? workspaceId});
  Future<void> archive(SpaceKind kind, String id);
  Future<void> restore(SpaceKind kind, String id);
  Future<void> delete(SpaceKind kind, String id);
  Future<List<SpaceMember>> members(SpaceKind kind, String id);
  Future<List<SpaceMember>> candidates(String workspaceId);
  Future<void> addMember(SpaceKind kind, String id, String userId, String role);
  Future<void> updateRole(
    SpaceKind kind,
    String id,
    String userId,
    String role,
  );
  Future<void> removeMember(SpaceKind kind, String id, String userId);
}

class CollaborationException implements Exception {
  const CollaborationException(this.message);
  final String message;
  @override
  String toString() => message;
}
