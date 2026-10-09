import 'dart:convert';

import 'package:equatable/equatable.dart';

enum ChatMessageKind { text, audio, videoMessage, file, poll, call, unknown }

class ChatMessageModel extends Equatable {
  const ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorAvatarUrl,
    this.kind = ChatMessageKind.text,
    this.durationSeconds,
    this.transcript,
    this.taskRef,
    this.callTitle,
    this.callMode,
    this.callStatus,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.attachmentDataUrl,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final authorValue = json['author'] ?? json['sender'] ?? json['user'];
    final author = authorValue is Map
        ? Map<String, dynamic>.from(authorValue)
        : const <String, dynamic>{};
    final rawText = (json['text'] ?? json['content'] ?? json['message'] ?? '')
        .toString();
    final callPayload = _callPayload(rawText);
    final attachmentValue = json['attachment'] ?? json['file'];
    final attachment = attachmentValue is Map
        ? Map<String, dynamic>.from(attachmentValue)
        : const <String, dynamic>{};
    final mediaData = _optionalText(
      json['mention'] ?? attachment['dataUrl'] ?? json['attachmentDataUrl'],
    );
    final kind =
        mediaData?.startsWith('data:video/') == true &&
            rawText.trimLeft().startsWith('📹')
        ? ChatMessageKind.videoMessage
        : _parseKind(json['kind'] ?? json['type'], callPayload, rawText);
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      threadId: (json['threadId'] ?? json['thread_id'] ?? '').toString(),
      authorId:
          (json['authorId'] ??
                  json['senderId'] ??
                  json['userId'] ??
                  author['id'] ??
                  '')
              .toString(),
      authorName:
          (author['name'] ??
                  json['authorName'] ??
                  json['senderName'] ??
                  'Пользователь')
              .toString(),
      text: rawText,
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now(),
      authorAvatarUrl:
          (author['avatarUrl'] ??
                  author['avatar_url'] ??
                  author['avatar'] ??
                  json['authorAvatarUrl'] ??
                  json['author_avatar_url'])
              ?.toString(),
      kind: kind,
      attachmentDataUrl: mediaData?.startsWith('data:') == true
          ? mediaData
          : null,
      durationSeconds: _parseInt(
        json['duration'] ??
            callPayload?['durationSec'] ??
            (kind == ChatMessageKind.videoMessage
                ? RegExp(r'(\d+)\s*[сs]').firstMatch(rawText)?.group(1)
                : null),
      ),
      transcript: _optionalText(json['transcript']),
      taskRef: _optionalText(json['taskRef'] ?? json['task_ref']),
      callTitle: _optionalText(callPayload?['title']),
      callMode: _optionalText(callPayload?['mode']),
      callStatus: _optionalText(callPayload?['status']),
      fileName: _optionalText(
        json['fileName'] ??
            json['filename'] ??
            json['originalName'] ??
            attachment['fileName'] ??
            attachment['name'] ??
            _fileNameFromText(rawText),
      ),
      mimeType: _optionalText(
        json['mimeType'] ??
            json['contentType'] ??
            attachment['mimeType'] ??
            attachment['contentType'],
      ),
      fileSize: _optionalText(
        json['fileSize'] ?? json['size'] ?? attachment['size'],
      ),
    );
  }

  final String id;
  final String threadId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? authorAvatarUrl;
  final ChatMessageKind kind;
  final int? durationSeconds;
  final String? transcript;
  final String? taskRef;
  final String? callTitle;
  final String? callMode;
  final String? callStatus;
  final String? fileName;
  final String? mimeType;
  final String? fileSize;
  final String? attachmentDataUrl;

  bool get isCall => kind == ChatMessageKind.call;
  bool get isFile => kind == ChatMessageKind.file;

  bool get isImageAttachment {
    if (!isFile) return false;
    if (mimeType?.toLowerCase().startsWith('image/') == true) return true;
    final extension = (fileName ?? '').toLowerCase().split('.').last;
    return const <String>{
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'heic',
    }.contains(extension);
  }

  String get attachmentLabel {
    final cleanText = text.replaceFirst(RegExp(r'^\s*📎\s*'), '').trim();
    return fileName ?? (cleanText.isEmpty ? 'Файл' : cleanText);
  }

  String get callHeading {
    final video = callMode?.toLowerCase() == 'video';
    final ended = callStatus?.toLowerCase() == 'ended';
    if (video && ended) return 'Видеозвонок завершён';
    if (video) return 'Видеозвонок';
    if (ended) return 'Звонок завершён';
    return 'Звонок';
  }

  String? get formattedDuration {
    final value = durationSeconds;
    if (value == null || value <= 0) return null;
    final minutes = value ~/ 60;
    final seconds = value % 60;
    return minutes == 0
        ? '$seconds сек.'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get initials => authorName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join()
      .toUpperCase();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'threadId': threadId,
    'authorId': authorId,
    'authorName': authorName,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'authorAvatarUrl': authorAvatarUrl,
    'kind': kind.name,
    if (durationSeconds != null) 'duration': durationSeconds,
    if (transcript != null) 'transcript': transcript,
    if (taskRef != null) 'taskRef': taskRef,
    if (fileName != null) 'fileName': fileName,
    if (mimeType != null) 'mimeType': mimeType,
    if (fileSize != null) 'fileSize': fileSize,
    if (attachmentDataUrl != null) 'attachmentDataUrl': attachmentDataUrl,
  };

  ChatMessageModel copyWith({String? id, String? text}) => ChatMessageModel(
    id: id ?? this.id,
    threadId: threadId,
    authorId: authorId,
    authorName: authorName,
    text: text ?? this.text,
    createdAt: createdAt,
    authorAvatarUrl: authorAvatarUrl,
    kind: kind,
    durationSeconds: durationSeconds,
    transcript: transcript,
    taskRef: taskRef,
    callTitle: callTitle,
    callMode: callMode,
    callStatus: callStatus,
    fileName: fileName,
    mimeType: mimeType,
    fileSize: fileSize,
    attachmentDataUrl: attachmentDataUrl,
  );

  static ChatMessageKind _parseKind(
    dynamic value,
    Map<String, dynamic>? call,
    String text,
  ) {
    if (call != null) return ChatMessageKind.call;
    if (text.trimLeft().startsWith('📎')) return ChatMessageKind.file;
    return switch (value?.toString().toUpperCase()) {
      null || '' || 'TEXT' => ChatMessageKind.text,
      'AUDIO' => ChatMessageKind.audio,
      'VIDEO_MSG' => ChatMessageKind.videoMessage,
      'FILE' => ChatMessageKind.file,
      'POLL' => ChatMessageKind.poll,
      'CALL' => ChatMessageKind.call,
      _ => ChatMessageKind.unknown,
    };
  }

  static String? _fileNameFromText(String text) {
    final clean = text.replaceFirst(RegExp(r'^\s*📎\s*'), '').trim();
    if (clean.isEmpty) return null;
    final separator = clean.indexOf(' · ');
    return (separator < 0 ? clean : clean.substring(0, separator)).trim();
  }

  static Map<String, dynamic>? _callPayload(String text) {
    final value = text.trim();
    if (!value.startsWith('{') || !value.endsWith('}')) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final payload = Map<String, dynamic>.from(decoded);
      return payload.containsKey('callId') || payload.containsKey('mode')
          ? payload
          : null;
    } catch (_) {
      return null;
    }
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  List<Object?> get props => [
    id,
    threadId,
    authorId,
    authorName,
    text,
    createdAt,
    authorAvatarUrl,
    kind,
    durationSeconds,
    transcript,
    taskRef,
    callTitle,
    callMode,
    callStatus,
    fileName,
    mimeType,
    fileSize,
    attachmentDataUrl,
  ];
}
