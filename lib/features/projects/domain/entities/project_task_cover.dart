import 'package:equatable/equatable.dart';

class ProjectTaskCover extends Equatable {
  const ProjectTaskCover({
    this.type,
    this.color,
    this.fileId,
    this.url,
    this.imageUrl,
    this.displayUrl,
  });

  final String? type;
  final String? color;
  final String? fileId;
  final String? url;
  final String? imageUrl;
  final String? displayUrl;

  ProjectTaskCover copyWith({
    String? type,
    String? color,
    String? fileId,
    String? url,
    String? imageUrl,
    String? displayUrl,
  }) => ProjectTaskCover(
    type: type ?? this.type,
    color: color ?? this.color,
    fileId: fileId ?? this.fileId,
    url: url ?? this.url,
    imageUrl: imageUrl ?? this.imageUrl,
    displayUrl: displayUrl ?? this.displayUrl,
  );

  @override
  List<Object?> get props => [type, color, fileId, url, imageUrl, displayUrl];
}
