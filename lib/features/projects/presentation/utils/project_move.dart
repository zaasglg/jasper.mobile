import '../../domain/entities/project_model.dart';
import 'project_tree.dart';

typedef ProjectMove = ({
  String workspaceId,
  String? parentId,
  String? anchorId,
  String placement,
});

ProjectMove? projectMove(
  ProjectModel source,
  ProjectModel target,
  String placement,
) {
  if (!const ['inside', 'before', 'after'].contains(placement) ||
      source.id == target.id ||
      source.workspaceId != target.workspaceId) {
    return null;
  }
  final inside = placement == 'inside';
  final parent = inside ? target.id : target.parentId;
  if (parent == source.id ||
      (parent != null && source.children.isNotEmpty) ||
      (inside && target.parentId != null) ||
      projectDescendants(source).any((child) => child.id == parent)) {
    return null;
  }
  return (
    workspaceId: source.workspaceId,
    parentId: parent,
    anchorId: inside ? null : target.id,
    placement: inside ? 'append' : placement,
  );
}

/// Rebuilds the tree without mutating the server snapshot used for validation.
List<ProjectModel> applyProjectMove(
  List<ProjectModel> projects,
  String id,
  ProjectMove move,
) {
  final roots = buildProjectTree(projects);
  final flat = <ProjectModel>[];
  void collect(ProjectModel project) {
    flat.add(project.copyWith(children: const []));
    for (final child in project.children) {
      collect(child);
    }
  }

  for (final root in roots) {
    collect(root);
  }
  final index = flat.indexWhere((project) => project.id == id);
  if (index < 0) return roots;
  final source = flat
      .removeAt(index)
      .copyWith(parentId: move.parentId, clearParentId: move.parentId == null);
  final anchor = flat.indexWhere((project) => project.id == move.anchorId);
  final insertion = anchor < 0
      ? flat.length
      : anchor + (move.placement == 'after' ? 1 : 0);
  flat.insert(insertion, source);
  return buildProjectTree(flat);
}
