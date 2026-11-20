import 'package:equatable/equatable.dart';
import 'storage_summary_content.dart';

class StorageSummary extends Equatable {
  const StorageSummary({
    required this.id,
    required this.roomId,
    required this.number,
    required this.authorName,
    required this.date,
    this.content = const StorageSummaryContent(),
  });
  final String id, roomId, number, authorName;
  final DateTime date;
  final StorageSummaryContent content;
  StorageSummary copyWith({
    String? id,
    String? roomId,
    String? number,
    String? authorName,
    DateTime? date,
    StorageSummaryContent? content,
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
