import 'package:equatable/equatable.dart';
import '../../../../core/network/api_constants.dart';
import '../../domain/entities/project_task_cover.dart';

class ProjectTaskCoverDto extends Equatable {
  const ProjectTaskCoverDto({
    this.type,
    this.color,
    this.fileId,
    this.url,
    this.imageUrl,
    this.displayUrl,
  });

  factory ProjectTaskCoverDto.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> detail = const {},
  }) {
    var source = (json['url'] ?? json['imageUrl'])?.toString();
    final fileId = json['fileId'];
    if (json['type'] == 'image' && fileId != null) {
      String? attachment;
      final files = detail['files'];
      if (files is List) {
        for (final file in files.whereType<Map>()) {
          if (file['id'] == fileId && file['dataUrl'] is String) {
            attachment = file['dataUrl'] as String;
            break;
          }
        }
      }
      final comments = detail['comments'];
      if (attachment == null && comments is List) {
        for (final comment in comments.whereType<Map>()) {
          final files = comment['files'];
          if (files is! List) continue;
          for (var index = 0; index < files.length; index++) {
            final file = files[index];
            if (file is Map &&
                fileId == 'cfile__${comment['id']}__$index' &&
                file['dataUrl'] is String) {
              attachment = file['dataUrl'] as String;
              break;
            }
          }
          if (attachment != null) break;
        }
      }
      source = attachment ?? source;
    }
    return ProjectTaskCoverDto(
      type: json['type']?.toString(),
      color: json['color']?.toString(),
      fileId: fileId?.toString(),
      url: json['url']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      displayUrl: _resolve(source),
    );
  }

  final String? type;
  final String? color;
  final String? fileId;
  final String? url;
  final String? imageUrl;
  final String? displayUrl;

  static String? _resolve(String? value) {
    final source = value?.trim();
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:image/')) return source;
    final uri = Uri.tryParse(source);
    if (uri == null) return null;
    final resolved = ApiConstants.origin.resolveUri(uri);
    return ['https', 'http'].contains(resolved.scheme)
        ? resolved.toString()
        : null;
  }

  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    if (color != null) 'color': color,
    if (fileId != null) 'fileId': fileId,
    if (url != null) 'url': url,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
  factory ProjectTaskCoverDto.fromEntity(ProjectTaskCover entity) =>
      ProjectTaskCoverDto(
        type: entity.type,
        color: entity.color,
        fileId: entity.fileId,
        url: entity.url,
        imageUrl: entity.imageUrl,
        displayUrl: entity.displayUrl,
      );
  ProjectTaskCover toEntity() => ProjectTaskCover(
    type: type,
    color: color,
    fileId: fileId,
    url: url,
    imageUrl: imageUrl,
    displayUrl: displayUrl,
  );
  ProjectTaskCoverDto copyWith({
    String? type,
    String? color,
    String? fileId,
    String? url,
    String? imageUrl,
    String? displayUrl,
  }) => ProjectTaskCoverDto.fromEntity(
    toEntity().copyWith(
      type: type,
      color: color,
      fileId: fileId,
      url: url,
      imageUrl: imageUrl,
      displayUrl: displayUrl,
    ),
  );
  @override
  List<Object?> get props => [type, color, fileId, url, imageUrl, displayUrl];
}
