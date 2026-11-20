import 'package:equatable/equatable.dart';
import '../../domain/entities/storage_analysis_result.dart';

class StorageAnalysisResultDto extends Equatable {
  const StorageAnalysisResultDto({
    this.created = 0,
    this.alreadyImported = false,
    this.undoBatchId,
  });
  final int created;
  final bool alreadyImported;
  final String? undoBatchId;
  factory StorageAnalysisResultDto.fromJson(Map<String, dynamic> json) =>
      StorageAnalysisResultDto(
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
  StorageAnalysisResultDto copyWith({
    int? created,
    bool? alreadyImported,
    String? undoBatchId,
  }) => StorageAnalysisResultDto(
    created: created ?? this.created,
    alreadyImported: alreadyImported ?? this.alreadyImported,
    undoBatchId: undoBatchId ?? this.undoBatchId,
  );
  factory StorageAnalysisResultDto.fromEntity(StorageAnalysisResult entity) =>
      StorageAnalysisResultDto(
        created: entity.created,
        alreadyImported: entity.alreadyImported,
        undoBatchId: entity.undoBatchId,
      );
  StorageAnalysisResult toEntity() => StorageAnalysisResult(
    created: created,
    alreadyImported: alreadyImported,
    undoBatchId: undoBatchId,
  );
  @override
  List<Object?> get props => [created, alreadyImported, undoBatchId];
}
