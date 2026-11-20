import '../entities/create_workspace_request.dart';
import '../entities/workspace_model.dart';

abstract interface class WorkspaceRepository {
  Future<List<WorkspaceModel>> getWorkspaces();

  Future<List<WorkspaceModel>> getArchivedWorkspaces();

  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request);
}
