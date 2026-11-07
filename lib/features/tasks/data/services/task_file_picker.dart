import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../models/task_detail_model.dart';
import '../../domain/repositories/task_details_repository.dart';

/// Matches the task-file format and 10 MB limit used by the website.
class TaskFilePicker {
  static const maxFileBytes = 10 * 1024 * 1024;
  static Future<List<TaskFileModel>> pick({
    String? author,
    String? authorId,
  }) async {
    final picked = await FilePicker.pickFiles();
    final files = <TaskFileModel>[];
    for (final file in picked) {
      final size = await file.length();
      if (size != null && size > maxFileBytes) {
        throw const TaskDetailsException(
          'Размер файла должен быть не больше 10 МБ.',
        );
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
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
          lookupMimeType(file.name, headerBytes: bytes.take(32).toList()) ??
          'application/octet-stream';
      files.add(
        TaskFileModel(
          id: 'file_${DateTime.now().microsecondsSinceEpoch}_${files.length}',
          name: file.name,
          size: bytes.length,
          type: type,
          dataUrl: 'data:$type;base64,${base64Encode(bytes)}',
          uploadedAt: DateTime.now(),
          uploadedByName: author,
          raw: {'uploadedById': ?authorId},
        ),
      );
    }
    return files;
  }
}
