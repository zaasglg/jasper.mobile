import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../data/models/task_detail_model.dart';
import '../../data/services/task_file_picker.dart';
import '../../domain/entities/task_attachment_source.dart';

Future<List<TaskFileModel>> pickTaskAttachments(
  BuildContext context, {
  String? author,
  String? authorId,
}) async {
  final source = await showAppActionMenu<TaskAttachmentSource>(
    context,
    title: 'Добавить вложение',
    eyebrow: 'Фото, видео и документы · до 10 МБ на файл',
    groups: const [
      [
        AppMenuAction(
          value: TaskAttachmentSource.gallery,
          label: 'Галерея',
          icon: LucideIcons.images,
        ),
        AppMenuAction(
          value: TaskAttachmentSource.files,
          label: 'Файлы',
          icon: LucideIcons.file,
        ),
      ],
    ],
  );
  if (source == null || !context.mounted) return [];
  final files = await TaskFilePicker.pick(
    source: source,
    author: author,
    authorId: authorId,
  );
  return context.mounted ? files : [];
}
