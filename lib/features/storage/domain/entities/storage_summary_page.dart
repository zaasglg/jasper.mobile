import 'package:equatable/equatable.dart';
import 'storage_summary.dart';

class StorageSummaryPage extends Equatable {
  const StorageSummaryPage({this.items = const [], this.total = 0});
  final List<StorageSummary> items;
  final int total;
  StorageSummaryPage copyWith({List<StorageSummary>? items, int? total}) =>
      StorageSummaryPage(
        items: items ?? this.items,
        total: total ?? this.total,
      );
  @override
  List<Object?> get props => [items, total];
}
