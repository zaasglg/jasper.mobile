import '../../data/models/create_project_request.dart';
import '../../data/models/project_model.dart';

abstract interface class ProjectRepository {
  Future<List<ProjectModel>> getProjects();

  Future<ProjectModel> createProject(CreateProjectRequest request);
}
