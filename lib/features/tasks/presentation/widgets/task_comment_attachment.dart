import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_ui_tokens.dart';
import '../../../storage/data/storage_collector.dart';
import '../../../storage/data/storage_models.dart';
import '../../data/models/task_detail_model.dart';

class TaskCommentAttachment extends StatelessWidget {
  const TaskCommentAttachment({
    required this.file,
    required this.onOpen,
    super.key,
  });

  final TaskFileModel file;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kind = StorageCollector.classify(file.name, file.type);
    final (icon, label) = switch (kind) {
      StorageFileKind.pdf => (LucideIcons.fileText, 'PDF'),
      StorageFileKind.image => (LucideIcons.image, 'Изображение'),
      StorageFileKind.video => (LucideIcons.circlePlay, 'Видео'),
      StorageFileKind.audio => (LucideIcons.music2, 'Аудио'),
      _ => (LucideIcons.fileText, 'Файл'),
    };
    final extension = RegExp(
      r'\.([a-zA-Z0-9]{1,10})$',
    ).firstMatch(file.name)?.group(1)?.toUpperCase();
    final type = kind == StorageFileKind.pdf ? 'PDF' : extension ?? label;
    final metadata = [
      type,
      if (file.size > 0) StorageCollector.formatSize(file.size),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          key: ValueKey('comment-file-${file.id}'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.smMd),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: label,
                  child: Icon(icon, color: colors.primary),
                ),
                const SizedBox(width: AppSpacing.smMd),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(context)?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        metadata,
                        style: AppTypography.caption(
                          context,
                        )?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
