import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../../domain/entities/task_attachment_source.dart';
import '../models/task_detail_model.dart';
import '../../domain/repositories/task_details_repository.dart';

/// Matches the task-file format and 10 MB limit used by the website.
class TaskFilePicker {
  static const maxFileBytes = 10 * 1024 * 1024;
  static Future<List<TaskFileModel>> pick({
    String? author,
    String? authorId,
    TaskAttachmentSource source = TaskAttachmentSource.files,
  }) async {
    if (source == TaskAttachmentSource.gallery) {
      final List<XFile> picked;
      try {
        picked = await ImagePicker().pickMultipleMedia(
          requestFullMetadata: false,
        );
      } on PlatformException catch (error) {
        throw TaskDetailsException(switch (error.code) {
          'photo_access_denied' ||
          'photo_access_restricted' ||
          'access_denied' =>
            'Нет доступа к галерее. Разрешите доступ к фото в настройках приложения.',
          'already_active' =>
            'Выбор фото уже открыт. Завершите его и попробуйте ещё раз.',
          _ => 'Не удалось открыть галерею. Попробуйте ещё раз.',
        });
      }
      return [
        for (var index = 0; index < picked.length; index++)
          await _read(
            name: picked[index].name,
            length: () => picked[index].length(),
            chunks: () => picked[index].openRead(),
            mimeType: picked[index].mimeType,
            index: index,
            author: author,
            authorId: authorId,
          ),
      ];
    }
    final picked = await FilePicker.pickFiles();
    final files = <TaskFileModel>[];
    for (final file in picked) {
      files.add(
        await _read(
          name: file.name,
          length: file.length,
          chunks: file.readAsByteStream,
          index: files.length,
          author: author,
          authorId: authorId,
        ),
      );
    }
    return files;
  }

  static Future<TaskFileModel> _read({
    required String name,
    required Future<int?> Function() length,
    required Stream<Uint8List> Function() chunks,
    required int index,
    String? mimeType,
    String? author,
    String? authorId,
  }) async {
    final size = await length();
    if (size != null && size > maxFileBytes) {
      throw const TaskDetailsException(
        'Размер файла должен быть не больше 10 МБ.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in chunks()) {
      if (builder.length + chunk.length > maxFileBytes) {
        throw const TaskDetailsException(
          'Размер файла должен быть не больше 10 МБ.',
        );
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw const TaskDetailsException('Выбранный файл пустой.');
    }
    final type =
        lookupMimeType(name, headerBytes: bytes.take(32).toList()) ??
        mimeType ??
        'application/octet-stream';
    return TaskFileModel(
      id: 'file_${DateTime.now().microsecondsSinceEpoch}_$index',
      name: name,
      size: bytes.length,
      type: type,
      dataUrl: 'data:$type;base64,${base64Encode(bytes)}',
      uploadedAt: DateTime.now(),
      uploadedByName: author,
      raw: {'uploadedById': ?authorId},
    );
  }
}
