import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'outbox survives restart and retries with the same UUID, then clears',
    () async {
      final claims = base64Url.encode(utf8.encode('{"sub":"me"}'));
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'x.$claims.x',
        'selected_workspace_id': 'w',
      });
      final adapter = _Adapter();
      ChatRepositoryImpl repository() => ChatRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      final first = repository();
      final local = await first.enqueueMessage('dm:me:peer', 'Текст');
      expect(local.deliveryStatus, 'sending');
      expect(
        local.clientId,
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ),
        ),
      );
      for (final failure in [
        DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
        DioExceptionType.badResponse,
      ]) {
        adapter.failure = failure;
        await expectLater(
          first.sendPending(local),
          throwsA(isA<DioException>()),
        );
        expect(
          (await first.pendingMessages(local.threadId)).single.text,
          'Текст',
        );
      }
      final restarted = repository();
      final restored = (await restarted.pendingMessages(local.threadId)).single;
      expect(restored.deliveryStatus, 'failed');
      expect(restored.clientId, local.clientId);
      adapter.failure = null;
      final sent = await restarted.sendPending(restored);
      expect(sent.deliveryStatus, 'delivered');
      expect(adapter.ids.toSet(), {local.clientId});
      expect(await restarted.pendingMessages(local.threadId), isEmpty);
      await first.dispose();
      await restarted.dispose();
    },
  );
  test(
    'pending text supports the legacy message validation contract',
    () async {
      final claims = base64Url.encode(utf8.encode('{"sub":"me"}'));
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'x.$claims.x',
        'selected_workspace_id': 'w',
      });
      final adapter = _Adapter()..legacy = true;
      final dio = Dio()..httpClientAdapter = adapter;
      final repository = ChatRepositoryImpl(
        dio,
        const WorkspaceSelectionStorage(FlutterSecureStorage()),
      );
      addTearDown(repository.dispose);
      addTearDown(dio.close);
      final local = await repository.enqueueMessage('channel', 'Привет');
      final sent = await repository.sendPending(local);
      expect(sent.id, 'server');
      expect(adapter.ids, [local.clientId]);
      expect(await repository.pendingMessages('channel'), isEmpty);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  bool legacy = false;
  DioExceptionType? failure;
  final ids = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.path == 'users/me') {
      return ResponseBody.fromString(
        '{"id":"me"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    expect(options.data['userId'], 'me');
    if (options.data['clientId'] != null) {
      ids.add(options.data['clientId'] as String);
    }
    if (legacy && options.data['clientId'] != null) {
      return ResponseBody.fromString(
        '{"message":["property clientId should not exist"]}',
        400,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'server',
        ...options.data as Map,
        'deliveryStatus': 'delivered',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
