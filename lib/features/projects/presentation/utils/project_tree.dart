import '../../domain/entities/project_model.dart';

/// Accepts both nested API responses and flat lists with parentId.
List<ProjectModel> buildProjectTree(List<ProjectModel> projects) {
  final nodes = <String, ProjectModel>{};
  final parents = <String, String>{};
  void collect(ProjectModel project, [String? parent]) {
    if (nodes.containsKey(project.id)) return;
    nodes[project.id] = project;
    final parentId = project.parentId ?? parent;
    if (parentId != null) parents[project.id] = parentId;
    for (final child in project.children) {
      collect(child, project.id);
    }
  }

  for (final project in projects) {
    collect(project);
  }
  final visited = <String>{};
  ProjectModel build(String id) {
    visited.add(id);
    return nodes[id]!.copyWith(
      parentId: parents[id],
      children: [
        for (final child in nodes.keys)
          if (parents[child] == id && !visited.contains(child)) build(child),
      ],
    );
  }

  return [
    for (final id in nodes.keys)
      if (!nodes.containsKey(parents[id]) && !visited.contains(id)) build(id),
    // Keep malformed cycles visible while cutting their recursive edges.
    for (final id in nodes.keys)
      if (!visited.contains(id)) build(id),
  ];
}

List<ProjectModel> projectDescendants(ProjectModel project) => [
  for (final child in project.children) ...[
    child,
    ...projectDescendants(child),
  ],
];

bool projectMatchesQuery(ProjectModel project, String query) =>
    '${project.name} ${project.code} ${project.description ?? ''}'
        .toLowerCase()
        .contains(query) ||
    project.children.any((child) => projectMatchesQuery(child, query));
