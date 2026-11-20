import 'package:equatable/equatable.dart';

class ManagedSpace extends Equatable {
  const ManagedSpace({
    required this.id,
    required this.name,
    this.workspaceId,
    this.code,
    this.description,
    this.color,
    this.logoUrl,
    this.isPinned = false,
  });
  final String id;
  final String name;
  final String? workspaceId;
  final String? code;
  final String? description;
  final String? color;
  final String? logoUrl;
  final bool isPinned;
  ManagedSpace copyWith({
    String? id,
    String? name,
    String? workspaceId,
    String? code,
    String? description,
    String? color,
    String? logoUrl,
    bool? isPinned,
  }) => ManagedSpace(
    id: id ?? this.id,
    name: name ?? this.name,
    workspaceId: workspaceId ?? this.workspaceId,
    code: code ?? this.code,
    description: description ?? this.description,
    color: color ?? this.color,
    logoUrl: logoUrl ?? this.logoUrl,
    isPinned: isPinned ?? this.isPinned,
  );
  @override
  List<Object?> get props => [
    id,
    name,
    workspaceId,
    code,
    description,
    color,
    logoUrl,
    isPinned,
  ];
}
