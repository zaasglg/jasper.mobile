import 'package:equatable/equatable.dart';

enum StorageSource { project, chat }

enum StorageCategory { media, documents, links, favorites, summaries }

enum StorageFileKind { image, video, audio, pdf, document, other, link }

class StorageScope extends Equatable {
  const StorageScope({
    required this.source,
    required this.id,
    required this.workspaceId,
    required this.title,
  });
  final StorageSource source;
  final String id, workspaceId, title;
  factory StorageScope.fromJson(Map<String, dynamic> json) => StorageScope(
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
  factory StorageItem.fromJson(Map<String, dynamic> json) => StorageItem(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    kind: StorageFileKind.values.firstWhere(
      (e) => e.name == json['kind'],
      orElse: () => StorageFileKind.other,
    ),
    date:
        DateTime.tryParse(json['date']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    dataUrl: json['dataUrl'] as String?,
    url: json['url'] as String?,
    sizeLabel: json['sizeLabel']?.toString() ?? '',
    authorId: json['authorId']?.toString() ?? '',
    authorName: json['authorName']?.toString() ?? '',
    taskId: json['taskId'] as String?,
    taskDisplayId: json['taskDisplayId']?.toString() ?? '',
    taskTitle: json['taskTitle']?.toString() ?? '',
    messageId: json['messageId'] as String?,
    favorited: json['favorited'] == true,
    mimeType: json['mimeType']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'date': date.toIso8601String(),
    'dataUrl': dataUrl,
    'url': url,
    'sizeLabel': sizeLabel,
    'authorId': authorId,
    'authorName': authorName,
    'taskId': taskId,
    'taskDisplayId': taskDisplayId,
    'taskTitle': taskTitle,
    'messageId': messageId,
    'favorited': favorited,
    'mimeType': mimeType,
  };
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

class StorageSummary extends Equatable {
  const StorageSummary({
    required this.id,
    required this.roomId,
    required this.number,
    required this.authorName,
    required this.date,
    this.content = const {},
  });
  final String id, roomId, number, authorName;
  final DateTime date;
  final Map<String, dynamic> content;
  factory StorageSummary.fromJson(Map<String, dynamic> json) {
    final author = json['createdBy'];
    final raw = json['content'];
    return StorageSummary(
      id: json['id']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      number: json['documentNumber']?.toString() ?? '',
      authorName: author is Map ? author['name']?.toString() ?? '' : '',
      date:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      content: raw is Map ? Map<String, dynamic>.from(raw) : const {},
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'roomId': roomId,
    'documentNumber': number,
    'createdBy': {'name': authorName},
    'createdAt': date.toIso8601String(),
    'content': content,
  };
  StorageSummary copyWith({
    String? id,
    String? roomId,
    String? number,
    String? authorName,
    DateTime? date,
    Map<String, dynamic>? content,
  }) => StorageSummary(
    id: id ?? this.id,
    roomId: roomId ?? this.roomId,
    number: number ?? this.number,
    authorName: authorName ?? this.authorName,
    date: date ?? this.date,
    content: content ?? this.content,
  );
  @override
  List<Object?> get props => [id, roomId, number, authorName, date, content];
}

class StorageSummaryPage extends Equatable {
  const StorageSummaryPage({this.items = const [], this.total = 0});
  final List<StorageSummary> items;
  final int total;
  factory StorageSummaryPage.fromJson(Map<String, dynamic> json) =>
      StorageSummaryPage(
        items: (json['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => StorageSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'total': total,
  };
  StorageSummaryPage copyWith({List<StorageSummary>? items, int? total}) =>
      StorageSummaryPage(
        items: items ?? this.items,
        total: total ?? this.total,
      );
  @override
  List<Object?> get props => [items, total];
}

class StorageAnalysisResult extends Equatable {
  const StorageAnalysisResult({
    this.created = 0,
    this.alreadyImported = false,
    this.undoBatchId,
  });
  final int created;
  final bool alreadyImported;
  final String? undoBatchId;
  factory StorageAnalysisResult.fromJson(Map<String, dynamic> json) =>
      StorageAnalysisResult(
        created:
            (json['created'] as num?)?.toInt() ??
            (json['items'] as List?)?.length ??
            0,
        alreadyImported: json['alreadyImported'] == true,
        undoBatchId: json['undoBatchId']?.toString(),
      );
  Map<String, dynamic> toJson() => {
    'created': created,
    'alreadyImported': alreadyImported,
    'undoBatchId': undoBatchId,
  };
  StorageAnalysisResult copyWith({
    int? created,
    bool? alreadyImported,
    String? undoBatchId,
  }) => StorageAnalysisResult(
    created: created ?? this.created,
    alreadyImported: alreadyImported ?? this.alreadyImported,
    undoBatchId: undoBatchId ?? this.undoBatchId,
  );
  @override
  List<Object?> get props => [created, alreadyImported, undoBatchId];
}
