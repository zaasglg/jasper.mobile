import 'dart:convert';
import 'package:html/parser.dart' as html;
import '../../../core/utils/html_text.dart';
import 'storage_models.dart';

class StorageCollector {
  static StorageFileKind classify(String name, [String mime = '']) {
    if (mime.startsWith('image/') ||
        RegExp(
          r'\.(jpe?g|png|gif|webp|bmp|svg)$',
          caseSensitive: false,
        ).hasMatch(name)) {
      return StorageFileKind.image;
    }
    if (mime.startsWith('video/') ||
        RegExp(
          r'\.(mp4|webm|mov|avi|mkv)$',
          caseSensitive: false,
        ).hasMatch(name)) {
      return StorageFileKind.video;
    }
    if (mime.startsWith('audio/') ||
        RegExp(
          r'\.(mp3|wav|ogg|m4a|aac|flac)$',
          caseSensitive: false,
        ).hasMatch(name)) {
      return StorageFileKind.audio;
    }
    if (mime == 'application/pdf' || name.toLowerCase().endsWith('.pdf')) {
      return StorageFileKind.pdf;
    }
    if (RegExp(
      r'\.(docx?|xlsx?|pptx?|txt|md|csv|rtf|odt|ods|odp)$',
      caseSensitive: false,
    ).hasMatch(name)) {
      return StorageFileKind.document;
    }
    return StorageFileKind.other;
  }

  static List<String> links(String? value) {
    if (value == null || value.isEmpty) return [];
    final fragment = html.parseFragment(value);
    final hrefs = fragment
        .querySelectorAll('a[href]')
        .map((e) => e.attributes['href'] ?? '')
        .where((e) => RegExp(r'^https?://', caseSensitive: false).hasMatch(e));
    final visible = htmlToPlainText(value);
    final urls = RegExp(
      r'''https?://[^\s<>"')\]]+''',
      caseSensitive: false,
    ).allMatches(visible).map((e) => e.group(0)!);
    return {...hrefs, ...urls}
        .map((e) => e.replaceFirst(RegExp(r'[.,;:!?]+$'), ''))
        .where((e) => Uri.tryParse(e)?.host.isNotEmpty == true)
        .toSet()
        .toList();
  }

  static Map<String, dynamic> object(dynamic value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return {};
      }
    }
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  static DateTime date(dynamic value, [DateTime? fallback]) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
      fallback ??
      DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime idDate(String id, DateTime fallback) {
    final match = RegExp(r'(?:^|_)(\d{13})(?:_|$)').firstMatch(id);
    final stamp = int.tryParse(match?.group(1) ?? '');
    return stamp == null
        ? fallback
        : DateTime.fromMillisecondsSinceEpoch(stamp);
  }

  static String formatSize(dynamic value) {
    if (value is String && double.tryParse(value) == null) return value;
    final bytes = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ'
        : '${(bytes / 1024).ceil()} КБ';
  }

  static String fileId(String taskId, String fileId) {
    final match = RegExp(r'^cfile__(.+)__(\d+)$').firstMatch(fileId);
    return match == null
        ? 'file:$taskId:$fileId'
        : 'cfile:$taskId:${match[1]}:${match[2]}';
  }

  static List<StorageItem> project(List<Map<String, dynamic>> tasks) {
    final items = <String, StorageItem>{};
    for (final task in tasks) {
      final taskId = task['id']?.toString() ?? '';
      if (taskId.isEmpty) continue;
      final detail = object(task['detail']);
      final taskDate = date(task['createdAt']);
      final displayId = task['displayId']?.toString() ?? '';
      final title = task['title']?.toString() ?? '';
      void file(
        Map<String, dynamic> file,
        String id,
        DateTime created,
        String author,
        String authorId,
      ) {
        final name = file['name']?.toString() ?? '';
        if (name.isEmpty) return;
        final type = file['type']?.toString() ?? '';
        items.putIfAbsent(
          id,
          () => StorageItem(
            id: id,
            name: name,
            kind: classify(name, type),
            mimeType: type,
            date: created,
            dataUrl: file['dataUrl']?.toString(),
            sizeLabel: formatSize(file['size']),
            authorName: author,
            authorId: authorId,
            taskId: taskId,
            taskDisplayId: displayId,
            taskTitle: title,
          ),
        );
      }

      final files = detail['files'];
      if (files is List) {
        for (final raw in files.whereType<Map>()) {
          final item = Map<String, dynamic>.from(raw);
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          file(
            item,
            fileId(taskId, id),
            date(item['uploadedAt'], idDate(id, taskDate)),
            item['uploadedByName']?.toString() ?? '',
            item['uploadedById']?.toString() ?? '',
          );
        }
      }
      final descriptionLinks = links(detail['description']?.toString());
      for (var i = 0; i < descriptionLinks.length; i++) {
        final id = 'desc-link:$taskId:$i';
        items[id] = StorageItem(
          id: id,
          name: descriptionLinks[i],
          url: descriptionLinks[i],
          kind: StorageFileKind.link,
          date: taskDate,
          taskId: taskId,
          taskDisplayId: displayId,
          taskTitle: title,
        );
      }
      final comments = detail['comments'];
      if (comments is! List) continue;
      for (final raw in comments.whereType<Map>()) {
        final comment = Map<String, dynamic>.from(raw);
        if (comment['deletedAt'] != null || comment['deleted_at'] != null) {
          continue;
        }
        final commentId = comment['id']?.toString() ?? '';
        final created = idDate(
          commentId,
          date(comment['createdAt'] ?? comment['time'], taskDate),
        );
        final author = comment['author']?.toString() ?? '';
        final authorId = comment['authorId']?.toString() ?? '';
        final attachments = comment['files'];
        if (attachments is List) {
          for (var i = 0; i < attachments.length; i++) {
            if (attachments[i] is Map) {
              file(
                Map<String, dynamic>.from(attachments[i] as Map),
                'cfile:$taskId:$commentId:$i',
                created,
                author,
                authorId,
              );
            }
          }
        }
        final urls = links(comment['text']?.toString());
        for (var i = 0; i < urls.length; i++) {
          final id = 'link:$taskId:$commentId:$i';
          items[id] = StorageItem(
            id: id,
            name: urls[i],
            url: urls[i],
            kind: StorageFileKind.link,
            date: created,
            authorId: authorId,
            authorName: author,
            taskId: taskId,
            taskDisplayId: displayId,
            taskTitle: title,
          );
        }
      }
    }
    return items.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<StorageItem> chat(List<Map<String, dynamic>> messages) {
    final items = <StorageItem>[];
    for (final message in messages) {
      final text = message['text']?.toString() ?? '';
      final author = object(message['user'] ?? message['author']);
      final attachment = object(message['attachment'] ?? message['file']);
      final match = RegExp(r'(?:^|\n\n)📎 (.+?) · ([^\n]+)$').firstMatch(text);
      final drive = RegExp(
        r'(?:^|\n\n)(📝|📊|📋|🖼️|📄|📎) (.+?) — (https?://\S+)$',
      ).firstMatch(text);
      final id = message['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final body =
          (message['mention'] ??
                  attachment['dataUrl'] ??
                  message['attachmentDataUrl'])
              ?.toString();
      final explicitName = (message['fileName'] ?? attachment['name'])
          ?.toString();
      final name = match?.group(1) ?? explicitName;
      if (name == null && drive == null) continue;
      final type =
          (message['mimeType'] ?? attachment['mimeType'] ?? attachment['type'])
              ?.toString() ??
          '';
      items.add(
        StorageItem(
          id: id,
          messageId: id,
          name: drive?.group(2) ?? name!,
          kind: drive != null ? StorageFileKind.link : classify(name!, type),
          date: date(message['createdAt']),
          dataUrl: drive == null ? body : null,
          url: drive?.group(3),
          sizeLabel:
              match?.group(2) ??
              formatSize(message['fileSize'] ?? attachment['size']),
          authorId: (author['id'] ?? message['userId'] ?? '').toString(),
          authorName: author['name']?.toString() ?? '',
          favorited: message['favorited'] == true,
          mimeType: type,
        ),
      );
    }
    return items..sort((a, b) => b.date.compareTo(a.date));
  }
}
