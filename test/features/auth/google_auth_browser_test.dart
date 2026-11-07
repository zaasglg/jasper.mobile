import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/auth/data/google_auth_browser.dart';

void main() {
  test('callback is bound to state and code exchange verifier', () async {
    String? challenge;
    final browser = GoogleAuthBrowser(
      authenticate: (url) async {
        final params = Uri.parse(url).queryParameters;
        expect(params['mobile'], '1');
        challenge = params['code_challenge'];
        return Uri(
          scheme: 'com.jospar.app',
          host: 'oauth',
          path: '/google',
          queryParameters: {'state': params['app_state']!, 'code': 'test-code'},
        ).toString();
      },
    );
    final grant = await browser.authorize();
    expect(grant?.code, 'test-code');
    expect(
      base64UrlEncode(
        sha256.convert(ascii.encode(grant!.verifier)).bytes,
      ).replaceAll('=', ''),
      challenge,
    );
  });

  test('rejects callback with wrong state', () async {
    final browser = GoogleAuthBrowser(
      authenticate: (_) async =>
          'com.jospar.app://oauth/google?code=code&state=wrong',
    );
    await expectLater(browser.authorize(), throwsFormatException);
  });

  test('browser cancellation returns no session', () async {
    final browser = GoogleAuthBrowser(
      authenticate: (_) async => throw PlatformException(code: 'CANCELED'),
    );
    expect(await browser.authorize(), isNull);
  });
}
