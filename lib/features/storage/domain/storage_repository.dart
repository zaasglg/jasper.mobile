import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'entities/storage_scope.dart';
import 'entities/storage_item.dart';
import 'entities/storage_summary.dart';
import 'entities/storage_summary_page.dart';
import 'entities/storage_analysis_result.dart';

abstract interface class StorageRepository {
  Future<List<StorageItem>> load(
    StorageScope scope, {
    CancelToken? cancelToken,
  });
  Future<String> currentUserId();
  Future<Set<String>> favorites(StorageScope scope);
  Future<void> setFavorite(StorageScope scope, StorageItem item, bool value);
  Future<void> deleteMessage(StorageScope scope, StorageItem item);
  Future<void> upload(StorageScope scope, String name, Uint8List bytes);
  Future<Uint8List> bytes(
    StorageScope scope,
    StorageItem item, {
    CancelToken? cancelToken,
  });
  Future<StorageSummaryPage> summaries(
    StorageScope scope,
    int skip, {
    CancelToken? cancelToken,
  });
  Future<StorageSummary> summary(
    StorageScope scope,
    StorageSummary item, {
    CancelToken? cancelToken,
  });
  Future<StorageAnalysisResult> analyze(
    StorageScope scope,
    StorageItem item, {
    CancelToken? cancelToken,
    void Function(String)? onProgress,
  });
  Future<void> undoImport(StorageScope scope, String batchId);
}

class StorageException implements Exception {
  const StorageException(this.message);
  final String message;
  @override
  String toString() => message;
}
