import 'package:equatable/equatable.dart';
import 'storage_enums.dart';

class StorageScope extends Equatable {
  const StorageScope({
    required this.source,
    required this.id,
    required this.workspaceId,
    required this.title,
  });
  final StorageSource source;
  final String id, workspaceId, title;
  StorageScope copyWith({
    StorageSource? source,
    String? id,
    String? workspaceId,
    String? title,
  }) => StorageScope(
    source: source ?? this.source,
    id: id ?? this.id,
    workspaceId: workspaceId ?? this.workspaceId,
    title: title ?? this.title,
  );
  @override
  List<Object?> get props => [source, id, workspaceId, title];
}
