import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../../domain/entities/assistant_attachment.dart';
import '../../domain/repositories/assistant_repository.dart';

class AssistantAttachmentPicker {
  static const maxFiles = 3, maxBytes = 8 * 1024 * 1024;
  static const blockedExtensions = {
    'exe',
    'dll',
    'com',
    'scr',
    'msi',
    'msix',
    'msixbundle',
    'appx',
    'appxbundle',
    'apk',
    'aab',
    'ipa',
    'app',
    'dmg',
    'pkg',
    'deb',
    'rpm',
    'elf',
    'bin',
    'sys',
    'drv',
    'dex',
    'jar',
    'class',
    'bat',
    'cmd',
    'ps1',
    'psm1',
    'psd1',
    'vbs',
    'vbe',
    'wsf',
    'wsh',
    'hta',
    'sh',
    'bash',
    'zsh',
    'fish',
    'csh',
    'command',
    'run',
    'desktop',
    'lnk',
    'url',
    'docm',
    'dotm',
    'xlsm',
    'xltm',
    'xlam',
    'pptm',
    'potm',
    'ppam',
    'sldm',
  };
  static void validateName(String name) {
    final normalized = name.trim().toLowerCase().replaceAll(
      RegExp(r'[. ]+$'),
      '',
    );
    if (normalized.isEmpty ||
        name.length > 240 ||
        RegExp(r'[/\\\x00-\x1f\u202a-\u202e\u2066-\u2069]').hasMatch(name)) {
      throw const AssistantException('Недопустимое имя файла.');
    }
    if (normalized.split('.').skip(1).any(blockedExtensions.contains)) {
      throw const AssistantException(
        'Исполняемые файлы, установщики и опасные скрипты прикреплять нельзя.',
      );
    }
  }

  static AssistantAttachment fromBytes(String name, Uint8List bytes) {
    validateName(name);
    if (bytes.isEmpty) {
      throw const AssistantException('Нельзя прикрепить пустой файл.');
    }
    if (bytes.length > maxBytes) {
      throw const AssistantException('Размер файла — до 8 МБ.');
    }
    final firstLine = String.fromCharCodes(bytes.take(256)).split('\n').first;
    final shellScript =
        firstLine.startsWith('#!') &&
        RegExp(
          r'\b(sh|bash|zsh|fish|csh|ksh|dash|pwsh|powershell)\b',
        ).hasMatch(firstLine);
    final head = bytes.take(4).toList();
    final magic = head.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (magic.startsWith('4d5a') ||
        magic == '7f454c46' ||
        const [
          'feedface',
          'feedfacf',
          'cefaedfe',
          'cffaedfe',
          'cafebabe',
          'bebafeca',
          '6465780a',
        ].contains(magic) ||
        shellScript) {
      throw const AssistantException('Обнаружен исполняемый файл или скрипт.');
    }
    final mime =
        (lookupMimeType(name) ??
                lookupMimeType(name, headerBytes: bytes.take(32).toList()) ??
                'application/octet-stream')
            .split(';')
            .first
            .trim()
            .toLowerCase();
    return AssistantAttachment(
      name: name,
      mimeType: mime,
      size: bytes.length,
      dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
    );
  }

  static Future<List<AssistantAttachment>> pick({
    required int remaining,
  }) async {
    if (remaining <= 0) {
      throw const AssistantException('Можно прикрепить до 3 файлов.');
    }
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.length > remaining) {
      throw const AssistantException('Можно прикрепить до 3 файлов.');
    }
    // Check every name and declared length before reading any file into memory.
    for (final file in files) {
      validateName(file.name);
      if ((await file.length() ?? 0) > maxBytes) {
        throw const AssistantException('Размер файла — до 8 МБ.');
      }
    }
    final result = <AssistantAttachment>[];
    for (final file in files) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (builder.length + chunk.length > maxBytes) {
          throw const AssistantException('Размер файла — до 8 МБ.');
        }
        builder.add(chunk);
      }
      result.add(fromBytes(file.name, builder.takeBytes()));
    }
    return result;
  }
}
