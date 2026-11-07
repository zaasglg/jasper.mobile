import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../../core/network/api_constants.dart';

typedef GoogleAuthCallback = Future<String> Function(String url);

class GoogleAuthBrowser {
  const GoogleAuthBrowser({GoogleAuthCallback? authenticate})
    : _authenticate = authenticate;
  final GoogleAuthCallback? _authenticate;

  Future<({String code, String verifier})?> authorize() async {
    final random = Random.secure();
    String nonce() => base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    final verifier = nonce();
    final state = nonce();
    final challenge = base64UrlEncode(
      sha256.convert(ascii.encode(verifier)).bytes,
    ).replaceAll('=', '');
    final url = Uri.parse(ApiConstants.baseUrl)
        .resolve('auth/google')
        .replace(
          queryParameters: {
            'mobile': '1',
            'code_challenge': challenge,
            'app_state': state,
          },
        );
    try {
      final result = _authenticate != null
          ? await _authenticate(url.toString())
          : await FlutterWebAuth2.authenticate(
              url: url.toString(),
              callbackUrlScheme: 'com.jospar.app',
            );
      final callback = Uri.parse(result);
      if (callback.scheme != 'com.jospar.app' ||
          callback.host != 'oauth' ||
          callback.path != '/google' ||
          callback.queryParameters['state'] != state) {
        throw const FormatException('Некорректный ответ авторизации Google.');
      }
      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const FormatException('Google не вернул код входа.');
      }
      return (code: code, verifier: verifier);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') return null;
      rethrow;
    }
  }
}
