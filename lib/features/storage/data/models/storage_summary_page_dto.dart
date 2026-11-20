import 'package:equatable/equatable.dart';
import '../../domain/entities/storage_summary_page.dart';
import 'storage_summary_dto.dart';

class StorageSummaryPageDto extends Equatable {
  const StorageSummaryPageDto({this.items = const [], this.total = 0});
  final List<StorageSummaryDto> items;
  final int total;
  factory StorageSummaryPageDto.fromJson(Map<String, dynamic> json) =>
      StorageSummaryPageDto(
        items: (json['items'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => StorageSummaryDto.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'total': total,
  };
  StorageSummaryPageDto copyWith({
    List<StorageSummaryDto>? items,
    int? total,
  }) => StorageSummaryPageDto(
    items: items ?? this.items,
    total: total ?? this.total,
  );
  factory StorageSummaryPageDto.fromEntity(StorageSummaryPage entity) =>
      StorageSummaryPageDto(
        total: entity.total,
        items: entity.items.map(StorageSummaryDto.fromEntity).toList(),
      );
  StorageSummaryPage toEntity() => StorageSummaryPage(
    total: total,
    items: items.map((e) => e.toEntity()).toList(),
  );
  @override
  List<Object?> get props => [items, total];
}
