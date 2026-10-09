import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class ChatAttachmentLoader {
  ChatAttachmentLoader(this._dio);
  final Dio _dio;

  Future<Uint8List> load(String messageId) async {
    final response = await _dio.get<dynamic>(
      'messages/${Uri.encodeComponent(messageId)}/attachment',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList((response.data as List).cast<int>());
    final type = response.headers.value('content-type') ?? '';
    if (type.contains('json')) {
      return decodePayload(jsonDecode(utf8.decode(bytes)));
    }
    if (bytes.length > 5 &&
        utf8.decode(bytes.take(5).toList(), allowMalformed: true) == 'data:') {
      return decodePayload(utf8.decode(bytes));
    }
    return bytes;
  }

  static Uint8List decodePayload(dynamic payload) {
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
        if (payload[key] != null) return decodePayload(payload[key]);
      }
    }
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
