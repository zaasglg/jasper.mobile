import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ChatAttachmentLoader {
  ChatAttachmentLoader(this._dio, {Dio? downloadDio})
    : _downloadDio = downloadDio;
  final Dio _dio;
  final Dio? _downloadDio;

  Future<Uint8List> load(
    String messageId, {
    String? workspaceId,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<dynamic>(
      'messages/${Uri.encodeComponent(messageId)}/attachment',
      options: Options(
        responseType: ResponseType.bytes,
        headers: workspaceId == null ? null : {'X-Workspace-Id': workspaceId},
      ),
      cancelToken: cancelToken,
    );
    final bytes = Uint8List.fromList((response.data as List).cast<int>());
    final type = response.headers.value('content-type') ?? '';
    final prefix = utf8
        .decode(bytes.take(64).toList(), allowMalformed: true)
        .trimLeft();
    if (type.contains('json') || prefix.startsWith('{')) {
      return _loadPayload(jsonDecode(utf8.decode(bytes)), cancelToken);
    }
    if (bytes.length > 5 &&
        utf8.decode(bytes.take(5).toList(), allowMalformed: true) == 'data:') {
      return decodePayload(utf8.decode(bytes));
    }
    return bytes;
  }

  Future<Uint8List> _loadPayload(
    dynamic payload,
    CancelToken? cancelToken,
  ) async {
    final value = _content(payload);
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      // Storage URLs have their own signatures; do not forward API auth headers.
      final client =
          _downloadDio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
      try {
        if (kDebugMode) {
          debugPrint('Chat attachment: downloading from ${uri.host}');
        }
        final response = await client.get<List<int>>(
          uri.toString(),
          options: Options(responseType: ResponseType.bytes),
          cancelToken: cancelToken,
        );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) {
          throw const FormatException('Вложение не содержит файла');
        }
        if (kDebugMode) {
          debugPrint(
            'Chat attachment: downloaded ${bytes.length} bytes; video format ${videoExtension(bytes)}',
          );
        }
        return Uint8List.fromList(bytes);
      } on DioException catch (error) {
        if (kDebugMode) {
          debugPrint(
            'Chat attachment: download failed ${error.type.name}; HTTP ${error.response?.statusCode}',
          );
        }
        rethrow;
      } finally {
        if (_downloadDio == null) client.close();
      }
    }
    return decodePayload(value);
  }

  static String videoExtension(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return 'webm';
    }
    return 'mp4';
  }

  static dynamic _content(dynamic payload) {
    if (payload is Map) {
      for (final key in [
        'dataUrl',
        'fileData',
        'url',
        'attachment',
        'data',
        'base64',
        'file',
        'content',
      ]) {
        if (payload[key] != null) return _content(payload[key]);
      }
    }
    return payload;
  }

  static Uint8List decodePayload(dynamic payload) {
    payload = _content(payload);
    if (payload is List) return Uint8List.fromList(payload.cast<int>());
    if (payload is String) {
      if (payload.startsWith('data:')) {
        return UriData.parse(payload).contentAsBytes();
      }
      return base64Decode(payload);
    }
    throw const FormatException('Вложение не содержит файла');
  }
}
