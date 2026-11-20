import 'package:equatable/equatable.dart';
import '../../domain/entities/storage_summary.dart';
import 'storage_summary_content_dto.dart';

class StorageSummaryDto extends Equatable {
  const StorageSummaryDto({
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
  factory StorageSummaryDto.fromJson(Map<String, dynamic> json) {
    final author = json['createdBy'];
    final raw = json['content'];
    return StorageSummaryDto(
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
  StorageSummaryDto copyWith({
    String? id,
    String? roomId,
    String? number,
    String? authorName,
    DateTime? date,
    Map<String, dynamic>? content,
  }) => StorageSummaryDto(
    id: id ?? this.id,
    roomId: roomId ?? this.roomId,
    number: number ?? this.number,
    authorName: authorName ?? this.authorName,
    date: date ?? this.date,
    content: content ?? this.content,
  );
  factory StorageSummaryDto.fromEntity(StorageSummary entity) =>
      StorageSummaryDto(
        id: entity.id,
        roomId: entity.roomId,
        number: entity.number,
        authorName: entity.authorName,
        date: entity.date,
        content: StorageSummaryContentDto.fromEntity(entity.content).toJson(),
      );
  StorageSummary toEntity() => StorageSummary(
    id: id,
    roomId: roomId,
    number: number,
    authorName: authorName,
    date: date,
    content: StorageSummaryContentDto.fromJson(content).toEntity(),
  );
  @override
  List<Object?> get props => [id, roomId, number, authorName, date, content];
}
