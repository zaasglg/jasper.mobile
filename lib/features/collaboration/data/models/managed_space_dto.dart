import 'package:equatable/equatable.dart';
import '../../domain/entities/managed_space.dart';

class ManagedSpaceDto extends Equatable {
  const ManagedSpaceDto({
    required this.id,
    required this.name,
    this.raw = const {},
  });
  factory ManagedSpaceDto.fromEntity(ManagedSpace entity) => ManagedSpaceDto(
    id: entity.id,
    name: entity.name,
    raw: {
      'workspaceId': entity.workspaceId,
      'code': entity.code,
      'description': entity.description,
      'color': entity.color,
      'logoUrl': entity.logoUrl,
      'isPinned': entity.isPinned,
    },
  );
  ManagedSpace toEntity() => ManagedSpace(
    id: id,
    name: name,
    workspaceId: raw['workspaceId']?.toString(),
    code: raw['code']?.toString(),
    description: raw['description']?.toString(),
    color: raw['color']?.toString(),
    logoUrl: raw['logoUrl']?.toString(),
    isPinned: raw['isPinned'] == true,
  );
  final String id;
  final String name;
  final Map<String, dynamic> raw;
  factory ManagedSpaceDto.fromJson(Map<String, dynamic> json) =>
      ManagedSpaceDto(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        raw: Map.of(json),
      );
  Map<String, dynamic> toJson() => {...raw, 'id': id, 'name': name};
  ManagedSpaceDto copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? raw,
  }) => ManagedSpaceDto(
    id: id ?? this.id,
    name: name ?? this.name,
    raw: raw ?? this.raw,
  );
  @override
  List<Object?> get props => [id, name, raw];
}
