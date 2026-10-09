import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/data/services/chat_attachment_loader.dart';

class _AttachmentAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, 'messages/message-1/attachment');
    return ResponseBody.fromString(
      jsonEncode({'dataUrl': 'data:image/png;base64,AQID'}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'loads JSON attachment API as decoded bytes instead of image JSON',
    () async {
      final dio = Dio()..httpClientAdapter = _AttachmentAdapter();
      addTearDown(dio.close);
      expect(await ChatAttachmentLoader(dio).load('message-1'), [1, 2, 3]);
    },
  );
  test('decodes API data URLs including nested attachment payloads', () {
    final bytes = [137, 80, 78, 71, 13, 10, 26, 10];
    final url = 'data:image/png;base64,${base64Encode(bytes)}';
    expect(
      ChatAttachmentLoader.decodePayload({
        'data': {'dataUrl': url},
      }),
      bytes,
    );
    expect(ChatAttachmentLoader.decodePayload({'attachment': url}), bytes);
    expect(
      ChatAttachmentLoader.decodePayload({'base64': base64Encode(bytes)}),
      bytes,
    );
  });
  test('reports missing content instead of decoding JSON as an image', () {
    expect(
      () => ChatAttachmentLoader.decodePayload({'name': 'file.png'}),
      throwsFormatException,
    );
  });
}
