import 'dart:convert';
import 'dart:typed_data';
import 'package:mime/mime.dart';

class ChatMediaPayload {
  static const maxFileBytes = 25 * 1024 * 1024;

  static Future<Uint8List> readBytes(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maxFileBytes) {
        throw const FormatException('Максимальный размер файла — 25 МБ.');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static String dataUrl(String name, Uint8List bytes, {String? mimeType}) {
    if (bytes.isEmpty) throw const FormatException('Файл пустой.');
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Максимальный размер файла — 25 МБ.');
    }
    final mime =
        mimeType ??
        lookupMimeType(name, headerBytes: bytes.take(32).toList()) ??
        'application/octet-stream';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static String fileText(String name, int size) {
    final label = size < 1024 * 1024
        ? '${(size / 1024).ceil()} КБ'
        : '${(size / (1024 * 1024)).toStringAsFixed(1)} МБ';
    return '📎 ${name.replaceAll(RegExp(r'[\r\n]'), ' ')} · $label';
  }
}
