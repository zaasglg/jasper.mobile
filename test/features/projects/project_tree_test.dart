import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/domain/entities/project_model.dart';
import 'package:jospar/features/projects/presentation/utils/project_tree.dart';

ProjectModel project(
  String id, {
  String? parent,
  List<ProjectModel> children = const [],
}) => ProjectModel(
  id: id,
  name: id,
  code: id,
  workspaceId: 'w',
  start: null,
  end: null,
  parentId: parent,
  children: children,
);

void main() {
  test('groups flat and nested children without duplicate cards', () {
    final tree = buildProjectTree([
      project('root', children: [project('nested')]),
      project('flat', parent: 'root'),
      project('nested', parent: 'root'),
      project('grandchild', parent: 'flat'),
    ]);
    expect(tree.map((e) => e.id), ['root']);
    expect(projectDescendants(tree.single).map((e) => e.id), [
      'nested',
      'flat',
      'grandchild',
    ]);
    expect(projectMatchesQuery(tree.single, 'grandchild'), isTrue);
    expect(projectMatchesQuery(tree.single, 'absent'), isFalse);
  });
  test('keeps orphaned and cyclic projects accessible without recursion', () {
    final tree = buildProjectTree([
      project('orphan', parent: 'missing'),
      project('a', parent: 'b'),
      project('b', parent: 'a'),
    ]);
    final ids = [
      for (final root in tree) root.id,
      for (final root in tree) ...projectDescendants(root).map((e) => e.id),
    ];
    expect(ids.toSet(), {'orphan', 'a', 'b'});
    expect(ids.length, 3);
  });
}
