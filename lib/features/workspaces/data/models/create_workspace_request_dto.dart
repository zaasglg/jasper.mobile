import 'package:equatable/equatable.dart';

import '../../domain/entities/create_workspace_request.dart';

class CreateWorkspaceRequestDto extends Equatable {
  const CreateWorkspaceRequestDto({required this.name, this.color});

  factory CreateWorkspaceRequestDto.fromJson(Map<String, dynamic> json) {
    return CreateWorkspaceRequestDto(
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
    );
  }

  factory CreateWorkspaceRequestDto.fromEntity(CreateWorkspaceRequest entity) =>
      CreateWorkspaceRequestDto(name: entity.name, color: entity.color);

  CreateWorkspaceRequest toEntity() =>
      CreateWorkspaceRequest(name: name, color: color);

  final String name;
  final String? color;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    if (color != null) 'color': color,
  };

  CreateWorkspaceRequestDto copyWith({String? name, String? color}) {
    return CreateWorkspaceRequestDto(
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => <Object?>[name, color];
}
