import '../entities/project_model.dart';
import '../entities/create_project_request.dart';

abstract interface class ProjectRepository {
  Future<List<ProjectModel>> getProjects();

  Future<ProjectModel> createProject(CreateProjectRequest request);
}
