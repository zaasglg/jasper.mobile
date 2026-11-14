import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/calls/data/call_events.dart';

void main() {
  test(
    'incoming state syncs on ready and calls only, without interval polling',
    () async {
      final stream = StreamController<Uint8List>();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            expect(options.path, 'realtime/events');
            handler.resolve(
              Response(
                requestOptions: options,
                data: ResponseBody(stream.stream, 200),
              ),
            );
          },
        ),
      );
      var changes = 0;
      final events = CallEvents(dio, () => changes++);
      events.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      stream.add(
        Uint8List.fromList(
          utf8.encode(
            'event: ready\ndata: {}\n\nevent: change\ndata: {"topic":"messages"}\n\nevent: change\ndata: {"topic":"calls"}\n\n',
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(changes, 2);
      expect(requests, 1);
      events.start();
      expect(requests, 1);
      events.stop();
      await stream.close();
      dio.close(force: true);
    },
  );
}
