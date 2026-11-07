import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../storage/data/storage_collector.dart';
import '../../../storage/data/storage_models.dart';
import '../../data/models/task_detail_model.dart';

class TaskFilesSection extends StatelessWidget {
  const TaskFilesSection({
    required this.files,
    required this.uploading,
    required this.onAdd,
    required this.onOpen,
    this.grid = false,
    super.key,
  });
  final List<TaskFileModel> files;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<TaskFileModel> onOpen;
  final bool grid;
  String _meta(TaskFileModel file) {
    final size = StorageCollector.formatSize(file.size);
    final date = file.uploadedAt?.toLocal();
    return [
      size,
      if (file.uploadedByName?.isNotEmpty == true) file.uploadedByName!,
      if (date != null) '${date.day}.${date.month}.${date.year}',
    ].join(' · ');
  }

  IconData _icon(TaskFileModel file) =>
      switch (StorageCollector.classify(file.name, file.type)) {
        StorageFileKind.image => LucideIcons.image,
        StorageFileKind.video => LucideIcons.circlePlay,
        StorageFileKind.audio => LucideIcons.music2,
        _ => LucideIcons.fileText,
      };
  Widget _thumbnail(
    BuildContext context,
    TaskFileModel file, {
    bool small = false,
  }) {
    Widget fallback() => Icon(
      _icon(file),
      size: small ? 16 : 24,
      color:
          file.type == 'application/pdf' ||
              file.name.toLowerCase().endsWith('.pdf')
          ? const Color(0xFFD85F55)
          : AppColors.accent,
    );
    Widget child = fallback();
    if (StorageCollector.classify(file.name, file.type) ==
            StorageFileKind.image &&
        file.dataUrl != null) {
      final url = file.dataUrl!;
      if (url.startsWith('data:')) {
        try {
          child = Image.memory(
            UriData.parse(url).contentAsBytes(),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: small ? 100 : 420,
            errorBuilder: (_, _, _) => fallback(),
          );
        } catch (_) {
          /* Keep the format icon for malformed image data. */
        }
      } else if (['http', 'https'].contains(Uri.tryParse(url)?.scheme)) {
        child = Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: small ? 100 : 420,
          errorBuilder: (_, _, _) => fallback(),
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(small ? 8 : 4),
      child: ColoredBox(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.badgeSurface,
        child: Center(child: child),
      ),
    );
  }

  Widget _card(BuildContext context, TaskFileModel file) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : AppColors.quietSurface,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('task-file-${file.id}'),
      onTap: () => onOpen(file),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: _thumbnail(context, file),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              _meta(file),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (files.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Нет прикреплённых файлов.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
      if (grid)
        GridView.builder(
          key: const Key('task-files-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: files.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent:
                194 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) => _card(context, files[index]),
        )
      else
        for (final file in files)
          ListTile(
            key: ValueKey('task-file-${file.id}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 2,
            ),
            leading: SizedBox(
              width: 36,
              height: 36,
              child: _thumbnail(context, file, small: true),
            ),
            title: Text(
              file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _meta(file),
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ),
            onTap: () => onOpen(file),
          ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            key: const Key('task-add-files'),
            onPressed: uploading ? null : onAdd,
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Icon(LucideIcons.plus, size: 16),
            label: Text(
              uploading ? 'Загрузка…' : 'Добавить файлы',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(44, 44),
            ),
          ),
          const Text(
            'До 10 МБ на файл',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    ],
  );
}

class TaskFilesViewToggle extends StatelessWidget {
  const TaskFilesViewToggle({
    required this.grid,
    required this.onChanged,
    super.key,
  });
  final bool grid;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _button(context, false, LucideIcons.list, 'Файлы списком'),
      _button(context, true, LucideIcons.layoutGrid, 'Файлы сеткой'),
    ],
  );
  Widget _button(
    BuildContext context,
    bool value,
    IconData icon,
    String label,
  ) {
    final selected = grid == value;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: () => onChanged(value),
          radius: 22,
          containedInkWell: true,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? (dark
                            ? Colors.white.withValues(alpha: .08)
                            : AppColors.badgeSurface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? (dark ? Colors.white : AppColors.ink)
                      : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
