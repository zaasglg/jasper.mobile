import 'package:equatable/equatable.dart';

class WorkspaceModel extends Equatable {
  const WorkspaceModel({
    required this.id,
    required this.name,
    this.color,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? color;
  final String? logoUrl;

  WorkspaceModel copyWith({
    String? id,
    String? name,
    String? color,
    String? logoUrl,
  }) {
    return WorkspaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, color, logoUrl];
}
