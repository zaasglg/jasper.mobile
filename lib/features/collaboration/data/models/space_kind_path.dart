import '../../domain/entities/space_kind.dart';

extension SpaceKindPath on SpaceKind {
  String get path => this == SpaceKind.project ? 'projects' : 'workspaces';
}
