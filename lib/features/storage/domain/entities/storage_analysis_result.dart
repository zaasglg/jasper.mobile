import 'package:equatable/equatable.dart';

class StorageAnalysisResult extends Equatable {
  const StorageAnalysisResult({
    this.created = 0,
    this.alreadyImported = false,
    this.undoBatchId,
  });
  final int created;
  final bool alreadyImported;
  final String? undoBatchId;
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
