import 'package:equatable/equatable.dart';
import 'storage_enums.dart';

class StorageItem extends Equatable {
  const StorageItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.date,
    this.dataUrl,
    this.url,
    this.sizeLabel = '',
    this.authorId = '',
    this.authorName = '',
    this.taskId,
    this.taskDisplayId = '',
    this.taskTitle = '',
    this.messageId,
    this.favorited = false,
    this.mimeType = '',
  });
  final String id,
      name,
      sizeLabel,
      authorId,
      authorName,
      taskDisplayId,
      taskTitle,
      mimeType;
  final StorageFileKind kind;
  final DateTime date;
  final String? dataUrl, url, taskId, messageId;
  final bool favorited;
  StorageCategory get category => kind == StorageFileKind.link
      ? StorageCategory.links
      : [
          StorageFileKind.image,
          StorageFileKind.video,
          StorageFileKind.audio,
        ].contains(kind)
      ? StorageCategory.media
      : StorageCategory.documents;
  bool get canOpen => url != null || dataUrl != null || messageId != null;
  bool get canAnalyze =>
      RegExp(
        r'\.(pdf|jpe?g|png|webp|bmp|tiff?)$',
        caseSensitive: false,
      ).hasMatch(name) &&
      category != StorageCategory.links;
  StorageItem copyWith({
    String? id,
    String? name,
    StorageFileKind? kind,
    DateTime? date,
    String? dataUrl,
    String? url,
    String? sizeLabel,
    String? authorId,
    String? authorName,
    String? taskId,
    String? taskDisplayId,
    String? taskTitle,
    String? messageId,
    bool? favorited,
    String? mimeType,
  }) => StorageItem(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    date: date ?? this.date,
    dataUrl: dataUrl ?? this.dataUrl,
    url: url ?? this.url,
    sizeLabel: sizeLabel ?? this.sizeLabel,
    authorId: authorId ?? this.authorId,
    authorName: authorName ?? this.authorName,
    taskId: taskId ?? this.taskId,
    taskDisplayId: taskDisplayId ?? this.taskDisplayId,
    taskTitle: taskTitle ?? this.taskTitle,
    messageId: messageId ?? this.messageId,
    favorited: favorited ?? this.favorited,
    mimeType: mimeType ?? this.mimeType,
  );
  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    date,
    dataUrl,
    url,
    sizeLabel,
    authorId,
    authorName,
    taskId,
    taskDisplayId,
    taskTitle,
    messageId,
    favorited,
    mimeType,
  ];
}
