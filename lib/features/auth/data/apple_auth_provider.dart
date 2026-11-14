import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'models/apple_sign_in_credential.dart';

abstract interface class AppleAuthProvider {
  Future<AppleSignInCredential?> authorize();
}

class NativeAppleAuthProvider implements AppleAuthProvider {
  const NativeAppleAuthProvider();

  @override
  Future<AppleSignInCredential?> authorize() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const FormatException('Apple не вернул токен идентификации.');
      }
      final userIdentifier = credential.userIdentifier;
      if (userIdentifier == null || userIdentifier.isEmpty) {
        throw const FormatException(
          'Apple не вернул идентификатор пользователя.',
        );
      }
      return AppleSignInCredential(
        authorizationCode: credential.authorizationCode,
        identityToken: identityToken,
        rawNonce: rawNonce,
        userIdentifier: userIdentifier,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const characters =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }
}
