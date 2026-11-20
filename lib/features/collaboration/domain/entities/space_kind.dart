enum SpaceKind { project, workspace }

extension SpaceKindLabel on SpaceKind {
  String get label => this == SpaceKind.project ? 'Проект' : 'Workspace';
}
