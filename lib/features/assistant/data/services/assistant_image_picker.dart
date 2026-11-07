import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../../domain/repositories/assistant_repository.dart';

class AssistantImagePicker {
  static const maxImages = 3, maxBytes = 8 * 1024 * 1024;
  static Future<List<String>> pick({required int remaining}) async {
    if (remaining <= 0) {
      throw const AssistantException('Можно прикрепить до 3 изображений.');
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    if (files.length > remaining) {
      throw const AssistantException('Можно прикрепить до 3 изображений.');
    }
    final images = <String>[];
    for (final file in files) {
      if ((await file.length() ?? 0) > maxBytes) {
        throw const AssistantException('Размер изображения — до 8 МБ.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const AssistantException('Размер изображения — до 8 МБ.');
        }
        bytes.add(chunk);
      }
      final data = bytes.takeBytes();
      final mime = lookupMimeType(
        file.name,
        headerBytes: data.take(32).toList(),
      );
      if (data.isEmpty ||
          ![
            'image/png',
            'image/jpeg',
            'image/webp',
            'image/gif',
          ].contains(mime)) {
        throw const AssistantException(
          'Выберите изображение PNG, JPEG, WebP или GIF.',
        );
      }
      images.add('data:$mime;base64,${base64Encode(data)}');
    }
    return images;
  }
}
