import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';

class _FailingStorage extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
  }) async {
    throw StateError('Secure storage unavailable');
  }
}

class _DelayedStorage extends FlutterSecureStorage {
  final writing = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
  }) async {
    if (value == 'candidate') {
      writing.complete();
      await release.future;
    }
    await super.write(key: key, value: value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final previous in [null, 'previous-session']) {
    test(
      'superseded secure write restores previous token ($previous)',
      () async {
        FlutterSecureStorage.setMockInitialValues({'access_token': ?previous});
        final secure = _DelayedStorage();
        final tokens = AuthTokenStorage(secure);
        await tokens.read();
        var current = true;
        final saving = tokens.saveIfCurrent('candidate', () => current);
        await secure.writing.future;
        current = false;
        secure.release.complete();
        expect(await saving, isFalse);
        expect(tokens.cachedToken, previous);
        expect(await tokens.read(), previous);
        expect(await secure.read(key: 'access_token'), previous);
        await tokens.save('new-session');
        expect(await tokens.read(), 'new-session');
      },
    );
  }
  test(
    'failed secure write does not publish token or block later operations',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = AuthTokenStorage(_FailingStorage());
      await expectLater(storage.save('secret-token'), throwsStateError);
      expect(storage.cachedToken, isNull);
      expect(await storage.read(), isNull);
    },
  );
}
