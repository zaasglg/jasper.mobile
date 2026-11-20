import 'package:equatable/equatable.dart';
import '../../domain/entities/storage_summary_content.dart';

class StorageSummaryContentDto extends Equatable {
  const StorageSummaryContentDto(this.value);
  final Map<String, dynamic> value;
  factory StorageSummaryContentDto.fromJson(Map<String, dynamic> json) =>
      StorageSummaryContentDto(Map.of(json));
  Map<String, dynamic> toJson() => Map.of(value);
  factory StorageSummaryContentDto.fromEntity(StorageSummaryContent entity) =>
      StorageSummaryContentDto({
        'participantDetails': entity.participantDetails,
        'keyDecisions': entity.keyDecisions,
        'allEntries': entity.allEntries,
        if (entity.duration != null) 'duration': entity.duration,
      });
  StorageSummaryContent toEntity() {
    List<Map<String, dynamic>> rows(Object? value) => (value as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return StorageSummaryContent(
      participantDetails: value['participantDetails'] is Map
          ? Map<String, dynamic>.from(value['participantDetails'] as Map)
          : const {},
      keyDecisions: rows(value['keyDecisions']),
      allEntries: rows(value['allEntries']),
      duration: value['duration']?.toString(),
    );
  }

  StorageSummaryContentDto copyWith({Map<String, dynamic>? value}) =>
      StorageSummaryContentDto(value ?? this.value);
  @override
  List<Object?> get props => [value];
}
