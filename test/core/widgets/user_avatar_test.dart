import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/core/network/user_avatar_repository.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/widgets/user_avatar.dart';

class _Tokens extends AuthTokenStorage {
  _Tokens() : super(const FlutterSecureStorage());
  String session = 'session-one';
  @override
  String? get cachedToken => session;
}

class _Adapter implements HttpClientAdapter {
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString(
      '{"data":{"id":"user","avatarUrl":"/uploads/avatar.png"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'relative avatar paths resolve to the site and invalid schemes are ignored',
    () {
      expect(
        resolveUserAvatarUrl('/uploads/avatar.png'),
        'https://jospar.me/uploads/avatar.png',
      );
      expect(
        resolveUserAvatarUrl('uploads/avatar.png'),
        'https://jospar.me/uploads/avatar.png',
      );
      expect(
        resolveUserAvatarUrl('https://example.test/photo.png'),
        'https://example.test/photo.png',
      );
      expect(resolveUserAvatarUrl('javascript:alert(1)'), isNull);
      expect(resolveUserAvatarUrl(''), isNull);
    },
  );

  test(
    'avatar lookup is shared across widgets and reset when the account changes',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      final tokens = _Tokens();
      final repository = UserAvatarRepository(dio, tokens);
      final avatars = await Future.wait([
        repository.avatarFor('user'),
        repository.avatarFor('user'),
      ]);
      expect(avatars, ['/uploads/avatar.png', '/uploads/avatar.png']);
      expect(adapter.requests, 1);
      tokens.session = 'session-two';
      await repository.avatarFor('user');
      expect(adapter.requests, 2);
      dio.close();
    },
  );

  testWidgets('shows a round fallback and looks up a missing URL by user ID', (
    tester,
  ) async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    sl.registerSingleton<UserAvatarRepository>(
      UserAvatarRepository(dio, _Tokens()),
    );
    addTearDown(() {
      sl.unregister<UserAvatarRepository>();
      dio.close();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(size: 36, userId: 'user', name: 'Данияр Исаев'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClipOval), findsOneWidget);
    expect(adapter.requests, 1);
    expect(tester.takeException(), isNull);
  });
}
