import 'package:equatable/equatable.dart';
import '../../domain/entities/storage_scope.dart';
import '../../domain/entities/storage_enums.dart';

class StorageScopeDto extends Equatable {
  const StorageScopeDto({
    required this.source,
    required this.id,
    required this.workspaceId,
    required this.title,
  });
  final StorageSource source;
  final String id, workspaceId, title;
  factory StorageScopeDto.fromJson(Map<String, dynamic> json) =>
      StorageScopeDto(
        source: json['source'] == 'chat'
            ? StorageSource.chat
            : StorageSource.project,
        id: json['id']?.toString() ?? '',
        workspaceId: json['workspaceId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );
  Map<String, dynamic> toJson() => {
    'source': source.name,
    'id': id,
    'workspaceId': workspaceId,
    'title': title,
  };
  StorageScopeDto copyWith({
    StorageSource? source,
    String? id,
    String? workspaceId,
    String? title,
  }) => StorageScopeDto(
    source: source ?? this.source,
    id: id ?? this.id,
    workspaceId: workspaceId ?? this.workspaceId,
    title: title ?? this.title,
  );
  factory StorageScopeDto.fromEntity(StorageScope entity) => StorageScopeDto(
    source: entity.source,
    id: entity.id,
    workspaceId: entity.workspaceId,
    title: entity.title,
  );
  StorageScope toEntity() => StorageScope(
    source: source,
    id: id,
    workspaceId: workspaceId,
    title: title,
  );
  @override
  List<Object?> get props => [source, id, workspaceId, title];
}
