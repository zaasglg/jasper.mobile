import 'package:equatable/equatable.dart';
import '../../domain/entities/space_member_project.dart';

class SpaceMemberProjectDto extends Equatable {
  const SpaceMemberProjectDto({required this.name});
  final String name;
  factory SpaceMemberProjectDto.fromJson(Object? value) =>
      SpaceMemberProjectDto(
        name: value is Map
            ? (value['name'] ?? value['title'] ?? 'Проект').toString()
            : value.toString(),
      );
  Map<String, dynamic> toJson() => {'name': name};
  factory SpaceMemberProjectDto.fromEntity(SpaceMemberProject entity) =>
      SpaceMemberProjectDto(name: entity.name);
  SpaceMemberProject toEntity() => SpaceMemberProject(name: name);
  SpaceMemberProjectDto copyWith({String? name}) =>
      SpaceMemberProjectDto(name: name ?? this.name);
  @override
  List<Object?> get props => [name];
}
