import 'models/storage_summary_page_dto.dart';
import 'models/storage_analysis_result_dto.dart';
import 'models/storage_summary_content_dto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../chat/data/services/chat_attachment_loader.dart';
import '../../chat/data/services/chat_media_payload.dart';
import '../domain/storage_repository.dart';
import 'storage_collector.dart';
import '../domain/entities/storage_scope.dart';
import '../domain/entities/storage_item.dart';
import '../domain/entities/storage_summary.dart';
import '../domain/entities/storage_summary_page.dart';
import '../domain/entities/storage_analysis_result.dart';
import '../domain/entities/storage_enums.dart';

class StorageRepositoryImpl implements StorageRepository {
  StorageRepositoryImpl(this.dio, this.storage, {Dio? downloadDio})
    : downloads =
          downloadDio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );
  final Dio dio, downloads;
  final FlutterSecureStorage storage;
  Options options(StorageScope scope) =>
      Options(headers: {'X-Workspace-Id': scope.workspaceId});
  Map<String, dynamic> object(dynamic value) {
    final map = StorageCollector.object(value);
    return map['data'] is Map ? StorageCollector.object(map['data']) : map;
  }

  @override
  Future<String> currentUserId() async {
    final user = object((await dio.get<dynamic>('users/me')).data);
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const StorageException('Не удалось определить пользователя');
    }
    return id;
  }

  @override
  Future<List<StorageItem>> load(
    StorageScope scope, {
    CancelToken? cancelToken,
  }) async {
    final rows = <String, Map<String, dynamic>>{};
    if (scope.source == StorageSource.project) {
      for (final archived in [false, true]) {
        // Track each query separately: a task may occur in both archive results.
        final seenIds = <String>{};
        for (var skip = 0; ; skip += 100) {
          final response = await dio.get<dynamic>(
            'project-tasks',
            queryParameters: {
              'projectId': scope.id,
              'archived': archived.toString(),
              'take': 100,
              'skip': skip,
            },
            options: options(scope),
            cancelToken: cancelToken,
          );
          final raw = response.data;
          final page = raw is List
              ? raw
              : object(raw)['items'] ?? object(raw)['data'];
          if (page is! List) {
            throw const StorageException('Не удалось прочитать файлы проекта');
          }
          var hasNewIds = false;
          for (final row in page.whereType<Map>()) {
            final map = Map<String, dynamic>.from(row);
            final id = map['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            if (seenIds.add(id)) hasNewIds = true;
            rows[id] = map;
          }
          if (page.isNotEmpty && !hasNewIds) {
            throw const StorageException(
              'Сервер вернул страницу файлов проекта без новых записей. Повторите загрузку.',
            );
          }
          if (page.length < 100) break;
        }
      }
      return StorageCollector.project(rows.values.toList());
    }
    String? cursor;
    final cursors = <String>{};
    do {
      final response = await dio.get<dynamic>(
        'messages',
        queryParameters: {
          'threadId': scope.id,
          'workspaceId': scope.workspaceId,
          'take': 100,
          'direction': 'backward',
          'cursor': ?cursor,
        },
        options: options(scope),
        cancelToken: cancelToken,
      );
      final raw = response.data;
      final map = StorageCollector.object(raw);
      final page = raw is List ? raw : map['data'] ?? map['items'];
      if (page is! List) {
        throw const StorageException('Не удалось прочитать вложения чата');
      }
      for (final row in page.whereType<Map>()) {
        final item = Map<String, dynamic>.from(row);
        rows[item['id'].toString()] = item;
      }
      cursor = map['nextCursor']?.toString();
      if (cursor != null && !cursors.add(cursor)) {
        throw const StorageException('Сервер повторил страницу вложений');
      }
    } while (cursor != null && cursor.isNotEmpty);
    return StorageCollector.chat(rows.values.toList());
  }

  Future<String> _favoriteKey(StorageScope scope) async =>
      'storage-favorites:${await currentUserId()}:${scope.workspaceId}:${scope.id}';
  @override
  Future<Set<String>> favorites(StorageScope scope) async {
    if (scope.source == StorageSource.chat) return {};
    final raw = await storage.read(key: await _favoriteKey(scope));
    if (raw == null) return {};
    return (jsonDecode(raw) as List).cast<String>().toSet();
  }

  @override
  Future<void> setFavorite(
    StorageScope scope,
    StorageItem item,
    bool value,
  ) async {
    if (scope.source == StorageSource.chat) {
      await dio.post<dynamic>(
        'messages/${Uri.encodeComponent(item.messageId!)}/favorite',
        options: options(scope),
      );
      return;
    }
    final key = await _favoriteKey(scope);
    final raw = await storage.read(key: key);
    final ids = raw == null
        ? <String>{}
        : (jsonDecode(raw) as List).cast<String>().toSet();
    value ? ids.add(item.id) : ids.remove(item.id);
    await storage.write(key: key, value: jsonEncode(ids.toList()));
  }

  @override
  Future<void> deleteMessage(StorageScope scope, StorageItem item) async {
    if (scope.source != StorageSource.chat || item.messageId == null) {
      throw const StorageException('Удалите файл в исходной задаче');
    }
    await dio.delete<dynamic>(
      'messages/${Uri.encodeComponent(item.messageId!)}',
      options: options(scope),
    );
  }

  @override
  Future<void> upload(StorageScope scope, String name, Uint8List bytes) async {
    if (scope.source != StorageSource.chat) {
      throw const StorageException('Добавьте файл в задаче проекта');
    }
    if (bytes.isEmpty || bytes.length > ChatMediaPayload.maxFileBytes) {
      throw const StorageException(
        'Размер файла должен быть от 1 байта до 25 МБ',
      );
    }
    await dio.post<dynamic>(
      'messages',
      options: options(scope),
      data: {
        'threadId': scope.id,
        'workspaceId': scope.workspaceId,
        'userId': await currentUserId(),
        'kind': 'TEXT',
        'text': ChatMediaPayload.fileText(name, bytes.length),
        'mention': ChatMediaPayload.dataUrl(name, bytes),
      },
    );
  }

  @override
  Future<Uint8List> bytes(
    StorageScope scope,
    StorageItem item, {
    CancelToken? cancelToken,
  }) async {
    final payload = item.dataUrl;
    if (payload != null && payload.startsWith('data:')) {
      return ChatAttachmentLoader.decodePayload(payload);
    }
    final uri = Uri.tryParse(payload ?? '');
    if (uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty) {
      final response = await downloads.get<List<int>>(
        uri.toString(),
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      if (response.data == null || response.data!.isEmpty) {
        throw const StorageException('Файл пуст');
      }
      return Uint8List.fromList(response.data!);
    }
    if (item.messageId != null) {
      return ChatAttachmentLoader(dio, downloadDio: downloads).load(
        item.messageId!,
        workspaceId: scope.workspaceId,
        cancelToken: cancelToken,
      );
    }
    throw const StorageException('Файл недоступен. Откройте исходную задачу.');
  }

  @override
  Future<StorageSummaryPage> summaries(
    StorageScope scope,
    int skip, {
    CancelToken? cancelToken,
  }) async => StorageSummaryPageDto.fromJson(
    object(
      (await dio.get<dynamic>(
        'video/thread-summaries',
        queryParameters: {
          'threadId': scope.id,
          'workspaceId': scope.workspaceId,
          'skip': skip,
          'take': 20,
        },
        options: options(scope),
        cancelToken: cancelToken,
      )).data,
    ),
  ).toEntity();
  @override
  Future<StorageSummary> summary(
    StorageScope scope,
    StorageSummary item, {
    CancelToken? cancelToken,
  }) async {
    final data = object(
      (await dio.get<dynamic>(
        'video/rooms/${Uri.encodeComponent(item.roomId)}/summaries/${Uri.encodeComponent(item.id)}',
        options: options(scope),
        cancelToken: cancelToken,
      )).data,
    );
    return item.copyWith(
      content: StorageSummaryContentDto.fromJson(
        StorageCollector.object(data['content'] ?? data),
      ).toEntity(),
    );
  }

  @override
  Future<StorageAnalysisResult> analyze(
    StorageScope scope,
    StorageItem item, {
    CancelToken? cancelToken,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Подготовка файла…');
    final file = await bytes(scope, item, cancelToken: cancelToken);
    onProgress?.call('Распознавание документа…');
    final job = object(
      (await dio.post<dynamic>(
        'ocr/jobs',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file, filename: item.name),
        }),
        options: options(scope),
        cancelToken: cancelToken,
      )).data,
    );
    final id = job['id']?.toString();
    if (id == null || id.isEmpty) {
      throw const StorageException('Сервер не создал задание распознавания');
    }
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (true) {
      if (cancelToken?.isCancelled == true) {
        throw cancelToken!.cancelError!;
      }
      final status = object(
        (await dio.get<dynamic>(
          'ocr/jobs/${Uri.encodeComponent(id)}',
          options: options(scope),
          cancelToken: cancelToken,
        )).data,
      );
      if (status['status'] == 'completed') break;
      if (status['status'] == 'failed') {
        throw StorageException(
          status['error']?.toString() ?? 'Не удалось распознать документ',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const StorageException(
          'Распознавание заняло слишком много времени',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    final result = object(
      (await dio.get<dynamic>(
        'ocr/jobs/${Uri.encodeComponent(id)}/result',
        options: options(scope),
        cancelToken: cancelToken,
      )).data,
    );
    final text = result['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const StorageException('В документе не найден текст');
    }
    final workspace = object(
      (await dio.get<dynamic>(
        'workspaces/${Uri.encodeComponent(scope.workspaceId)}',
        options: options(scope),
        cancelToken: cancelToken,
      )).data,
    );
    onProgress?.call('Создание задач в инбоксе…');
    final source = Uri.tryParse(item.dataUrl ?? '');
    final response = await dio.post<dynamic>(
      'ocr/tasks',
      options: options(scope)..receiveTimeout = const Duration(seconds: 110),
      cancelToken: cancelToken,
      data: {
        'text': text.length > 12000 ? text.substring(0, 12000) : text,
        'sourceHash': result['sourceHash'],
        'filename': item.name.length > 255
            ? item.name.substring(0, 255)
            : item.name,
        'workspaceId': scope.workspaceId,
        'timeZone': workspace['timeZone'] ?? workspace['timezone'] ?? 'UTC',
        if (source?.scheme == 'https') 'sourceFile': {'dataUrl': item.dataUrl},
      },
    );
    return StorageAnalysisResultDto.fromJson(object(response.data)).toEntity();
  }

  @override
  Future<void> undoImport(StorageScope scope, String batchId) async {
    await dio.post<dynamic>(
      'ocr/tasks/undo',
      data: {'batchId': batchId},
      options: options(scope),
    );
  }
}
