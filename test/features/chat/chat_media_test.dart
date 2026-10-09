import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/data/models/chat_message_model.dart';
import 'package:jospar/features/chat/data/services/chat_media_payload.dart';
import 'package:jospar/features/chat/presentation/widgets/file_attachment_sheet.dart';
import 'package:jospar/features/chat/presentation/widgets/video_note_message.dart';

final class _File extends PlatformFile {
  _File(this.name);
  @override
  final String name;
  @override
  Uri get uri => Uri.file('/tmp/$name');
  @override
  get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => 3;
  @override
  Future<int?> length() async => 3;
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);
  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.value(Uint8List.fromList([1, 2, 3]));
}

void main() {
  test(
    'file and video payloads match the website format and round trip through message model',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final fileUrl = ChatMediaPayload.dataUrl('report.pdf', bytes);
      final file = ChatMessageModel.fromJson({
        'id': 'file',
        'kind': 'TEXT',
        'text': ChatMediaPayload.fileText('report.pdf', 3),
        'mention': fileUrl,
      });
      expect(file.isFile, isTrue);
      expect(file.fileName, 'report.pdf');
      expect(file.attachmentDataUrl, fileUrl);
      expect(
        ChatMessageModel.fromJson(file.toJson()).attachmentDataUrl,
        fileUrl,
      );
      expect(UriData.parse(fileUrl).contentAsBytes(), bytes);
      final video = ChatMessageModel.fromJson({
        'id': 'video',
        'kind': 'TEXT',
        'text': '📹 видео 10с',
        'mention': 'data:video/mp4;base64,${base64Encode(bytes)}',
        'duration': 10,
      });
      expect(video.kind, ChatMessageKind.videoMessage);
      expect(video.durationSeconds, 10);
      expect(
        video.copyWith(text: video.text).attachmentDataUrl,
        video.attachmentDataUrl,
      );
    },
  );
  test(
    'streaming file reads reject oversized files and empty payloads',
    () async {
      expect(
        () => ChatMediaPayload.dataUrl('empty.txt', Uint8List(0)),
        throwsFormatException,
      );
      await expectLater(
        ChatMediaPayload.readBytes(
          Stream.fromIterable([
            Uint8List(ChatMediaPayload.maxFileBytes),
            Uint8List(1),
          ]),
        ),
        throwsFormatException,
      );
    },
  );
  testWidgets('file retry does not send files already uploaded', (
    tester,
  ) async {
    final files = [_File('one.pdf'), _File('two.pdf')];
    final names = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileAttachmentSheet(
            files: files,
            onSend: (text, url) async {
              names.add(text);
              if (text.contains('two.pdf')) return false;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Отправить (2)'));
    await tester.pumpAndSettle();
    expect(find.text('one.pdf'), findsNothing);
    expect(find.text('two.pdf'), findsOneWidget);
    expect(names, hasLength(2));
    // Keep the sheet mounted after a second failure so the test can inspect retry state.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileAttachmentSheet(
            files: files,
            onSend: (text, url) async {
              names.add(text);
              return false;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Отправить (1)'));
    await tester.pumpAndSettle();
    expect(names.last, contains('two.pdf'));
    expect(names.where((text) => text.contains('one.pdf')), hasLength(1));
  });
  testWidgets(
    'video note renders as a round playable message without base64 text',
    (tester) async {
      final message = ChatMessageModel.fromJson({
        'id': 'video',
        'kind': 'TEXT',
        'text': '📹 видео 10с',
        'duration': 10,
        'mention': 'data:video/mp4;base64,AQID',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VideoNoteMessage(message: message)),
        ),
      );
      expect(find.byKey(const Key('video-note-video')), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.textContaining('base64'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
