import '../../data/models/create_workspace_request.dart';
import '../../data/models/workspace_model.dart';

abstract interface class WorkspaceRepository {
  Future<List<WorkspaceModel>> getWorkspaces();

  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request);
}
