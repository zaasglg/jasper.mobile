import '../entities/project_model.dart';
import '../entities/create_project_request.dart';

abstract interface class ProjectRepository {
  Future<List<ProjectModel>> getProjects();
  Future<void> setPinned(String id, bool pinned);
  Future<void> archiveProject(String id);

  Future<void> moveProject(
    String id, {
    required String workspaceId,
    String? parentId,
    String? anchorId,
    required String placement,
  });

  Future<ProjectModel> createProject(CreateProjectRequest request);
}
