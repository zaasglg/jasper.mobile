import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/features/kanban/data/models/card_view_settings.dart';
import 'package:jospar/features/kanban/data/storage/card_view_storage.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'cloud fields match web names and preferences are isolated by account and project',
    () async {
      const secure = FlutterSecureStorage();
      final auth = AuthTokenStorage(secure);
      await auth.save(_token('u1'));
      final adapter = _PreferencesAdapter();
      final storage = CardViewStorage(
        secure,
        dio: Dio()..httpClientAdapter = adapter,
        tokenStorage: auth,
      );
      await storage.save(
        const CardViewSettings(hidden: {CardField.id, CardField.comments}),
        workspaceId: 'w',
        projectId: 'p',
      );
      final body = adapter.requests.last.data as Map;
      expect(body['userId'], 'u1');
      expect(body['value']['number'], false);
      expect(body['value']['discussion'], false);
      expect(body['value']['cover'], true);
      expect((await storage.read(workspaceId: 'w', projectId: 'p')).hidden, {
        CardField.id,
        CardField.comments,
      });
      expect(
        (await storage.read(workspaceId: 'w', projectId: 'other')).hidden,
        isEmpty,
      );
      await auth.save(_token('u2'));
      expect(
        (await storage.read(workspaceId: 'w', projectId: 'p')).hidden,
        isEmpty,
      );
    },
  );
  test(
    'offline cloud reads fall back to scoped cache and writes report sync failure',
    () async {
      const secure = FlutterSecureStorage();
      final auth = AuthTokenStorage(secure);
      await auth.save(_token('u'));
      final adapter = _PreferencesAdapter();
      final storage = CardViewStorage(
        secure,
        dio: Dio()..httpClientAdapter = adapter,
        tokenStorage: auth,
      );
      await storage.save(
        const CardViewSettings(hidden: {CardField.files}),
        workspaceId: 'w',
        projectId: 'p',
      );
      adapter.fail = true;
      expect(
        (await storage.read(
          workspaceId: 'w',
          projectId: 'p',
        )).shows(CardField.files),
        false,
      );
      expect(
        storage.save(
          const CardViewSettings(hidden: {CardField.cover}),
          workspaceId: 'w',
          projectId: 'p',
        ),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await storage.read(
          workspaceId: 'w',
          projectId: 'p',
        )).shows(CardField.cover),
        false,
      );
    },
  );
  test(
    'rapid toggles are serialized so older requests cannot overwrite newer preferences',
    () async {
      const secure = FlutterSecureStorage();
      final auth = AuthTokenStorage(secure);
      await auth.save(_token('u'));
      final adapter = _PreferencesAdapter()..hold = Completer<void>();
      final storage = CardViewStorage(
        secure,
        dio: Dio()..httpClientAdapter = adapter,
        tokenStorage: auth,
      );
      final first = storage.save(
        const CardViewSettings(hidden: {CardField.id}),
        workspaceId: 'w',
        projectId: 'p',
      );
      final second = storage.save(
        const CardViewSettings(hidden: {CardField.cover}),
        workspaceId: 'w',
        projectId: 'p',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(adapter.requests.length, 1);
      adapter.hold!.complete();
      await Future.wait([first, second]);
      expect((await storage.read(workspaceId: 'w', projectId: 'p')).hidden, {
        CardField.cover,
      });
    },
  );
}

String _token(String id) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.signature';

class _PreferencesAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final values = <String, dynamic>{};
  bool fail = false;
  Completer<void>? hold;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (fail) {
      return ResponseBody.fromString(
        '{}',
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final map = options.method == 'PUT'
        ? options.data as Map
        : options.queryParameters;
    final key = '${map['userId']}:${map['workspaceId']}:${map['projectId']}';
    if (options.method == 'PUT') {
      if (hold != null) await hold!.future;
      values[key] = map['value'];
    }
    return ResponseBody.fromString(
      jsonEncode({'value': values[key]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
