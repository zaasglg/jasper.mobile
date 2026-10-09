import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/services/chat_media_payload.dart';

class FileAttachmentSheet extends StatefulWidget {
  const FileAttachmentSheet({
    super.key,
    required this.files,
    required this.onSend,
  });
  final List<PlatformFile> files;
  final Future<bool> Function(String text, String dataUrl) onSend;
  @override
  State<FileAttachmentSheet> createState() => _FileAttachmentSheetState();
}

class _FileAttachmentSheetState extends State<FileAttachmentSheet> {
  late final List<PlatformFile> _pending = [...widget.files];
  bool _sending = false;
  String? _error;
  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      while (_pending.isNotEmpty) {
        final file = _pending.first;
        final length = await file.length();
        if (length != null && length > ChatMediaPayload.maxFileBytes) {
          throw const FormatException(
            'Максимальный размер файла — 25 МБ. Уберите большой файл из списка.',
          );
        }
        final bytes = await ChatMediaPayload.readBytes(file.readAsByteStream());
        final text = ChatMediaPayload.fileText(file.name, bytes.length);
        final url = ChatMediaPayload.dataUrl(file.name, bytes);
        if (!mounted) return;
        if (!await widget.onSend(text, url)) {
          if (mounted) {
            setState(
              () => _error =
                  'Не удалось отправить ${file.name}. Файл сохранён для повторной отправки.',
            );
          }
          return;
        }
        if (!mounted) return;
        setState(() => _pending.removeAt(0));
      }
      if (mounted) Navigator.pop(context);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось прочитать или отправить файл. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Отправить файлы',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const Text(
              'До 25 МБ на файл',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: ListView(
                shrinkWrap: true,
                children: _pending
                    .map(
                      (file) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          LucideIcons.file,
                          color: AppColors.accent,
                        ),
                        title: Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Убрать файл',
                          onPressed: _sending
                              ? null
                              : () {
                                  setState(() => _pending.remove(file));
                                  if (_pending.isEmpty) Navigator.pop(context);
                                },
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            FilledButton.icon(
              onPressed: _sending || _pending.isEmpty ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.sendHorizontal),
              label: Text(
                _sending ? 'Отправка…' : 'Отправить (${_pending.length})',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
